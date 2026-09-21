"""Browser checks for the static site. Install playwright and Chromium before running."""

from __future__ import annotations

import functools
import http.server
import json
import os
import threading
import unittest
from pathlib import Path
from urllib.parse import unquote, urlparse

from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[1]
SITE = ROOT / "site"
REPO = "https://github.com/vannt-dev/ai-engineering-skills"


class QuietHandler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, format: str, *args: object) -> None:
        pass


class SiteChecks(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.server = http.server.ThreadingHTTPServer(
            ("127.0.0.1", 0), functools.partial(QuietHandler, directory=str(SITE))
        )
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()
        cls.runtime = sync_playwright().start()
        cls.browser = cls.runtime.chromium.launch()
        cls.url = f"http://127.0.0.1:{cls.server.server_port}/"

    @classmethod
    def tearDownClass(cls) -> None:
        cls.browser.close()
        cls.runtime.stop()
        cls.server.shutdown()
        cls.server.server_close()
        cls.thread.join()

    def setUp(self) -> None:
        self.context = self.browser.new_context(
            viewport={"width": 1440, "height": 1000}
        )
        self.page = self.context.new_page()
        self.errors: list[str] = []
        self.page.on("pageerror", lambda error: self.errors.append(str(error)))
        self.page.goto(self.url, wait_until="networkidle")

    def tearDown(self) -> None:
        self.context.close()
        self.assertEqual([], self.errors)

    def test_responsive_layout_and_screenshots(self) -> None:
        for width in (320, 390, 768, 1440):
            with self.subTest(width=width):
                self.page.set_viewport_size({"width": width, "height": 1000})
                self.assertEqual(
                    0,
                    self.page.evaluate(
                        "Math.max(0, document.documentElement.scrollWidth - innerWidth)"
                    ),
                )
                self.assertTrue(self.page.get_by_role("heading", level=1).is_visible())
                self.assertTrue(
                    self.page.get_by_role("link", name="Get the skills").is_visible()
                )
                if directory := os.environ.get("SITE_SCREENSHOT_DIR"):
                    output = Path(directory).resolve()
                    output.mkdir(parents=True, exist_ok=True)
                    self.page.screenshot(
                        path=str(output / f"landing-{width}.png"), full_page=True
                    )
                    self.page.screenshot(path=str(output / f"viewport-{width}.png"))
                    self.page.locator("#install").screenshot(
                        path=str(output / f"install-{width}.png")
                    )
                    self.page.evaluate("window.scrollTo(0, 0)")

    def test_catalog_matches_manifest(self) -> None:
        expected = json.loads((ROOT / "skillset.json").read_text(encoding="utf-8"))[
            "skills"
        ]
        actual = self.page.locator("[data-skill]").evaluate_all(
            "cards => cards.map(c => ({name:c.dataset.skill, category:c.dataset.category}))"
        )
        self.assertEqual(
            [{"name": item["name"], "category": item["category"]} for item in expected],
            actual,
        )

    def test_filter_search_and_reset(self) -> None:
        self.page.get_by_role("button", name="Engineering 7", exact=True).click()
        self.assertEqual(7, self.page.locator("[data-skill]:visible").count())
        self.page.get_by_role("searchbox", name="Search skills").fill("python")
        self.assertEqual(1, self.page.locator("[data-skill]:visible").count())
        self.assertTrue(
            self.page.locator('[data-skill="python-engineering"]').is_visible()
        )
        self.page.get_by_role("searchbox", name="Search skills").fill(
            "no-matching-skill"
        )
        self.assertTrue(
            self.page.get_by_role("heading", name="No matching skills.").is_visible()
        )
        self.page.get_by_role("button", name="Reset filters").click()
        self.assertEqual(15, self.page.locator("[data-skill]:visible").count())
        self.assertEqual(
            "true",
            self.page.get_by_role("button", name="All skills 15").get_attribute(
                "aria-pressed"
            ),
        )
        self.page.get_by_role("button", name="Workflow 8", exact=True).click()
        self.assertEqual(8, self.page.locator("[data-skill]:visible").count())

    def test_install_commands_for_supported_tools_and_scopes(self) -> None:
        for tool in ("Universal", "Codex", "Claude", "OpenCode", "Antigravity"):
            self.page.get_by_label("CHOOSE YOUR TOOL").select_option(tool)
            command = self.page.locator("#install-command").inner_text()
            self.assertIn(f"-Target {tool} -Scope User -WhatIf", command)
            self.assertTrue(
                command.startswith(f"git clone {REPO}.git\ncd ai-engineering-skills\n")
            )
        self.page.get_by_role("radio", name="One project").check()
        self.page.get_by_label("EXISTING PROJECT PATH").fill("../team's project")
        self.page.get_by_role("checkbox", name="Preview first").uncheck()
        command = self.page.locator("#install-command").inner_text()
        self.assertIn("-Scope Project -ProjectRoot '../team''s project'", command)
        self.assertNotIn("-WhatIf", command)
        self.page.get_by_role("radio", name="Your user account").check()
        self.assertNotIn(
            "-ProjectRoot", self.page.locator("#install-command").inner_text()
        )
        self.assertFalse(self.page.get_by_label("EXISTING PROJECT PATH").is_visible())

    def test_copy_and_permission_denied_fallback(self) -> None:
        self.context.grant_permissions(["clipboard-read", "clipboard-write"])
        self.page.get_by_role("button", name="Copy installation commands").click()
        self.page.wait_for_function(
            "document.querySelector('#copy-status').textContent.includes('Commands copied')"
        )
        self.assertEqual(
            self.page.locator("#install-command").inner_text(),
            self.page.evaluate("navigator.clipboard.readText()").replace("\r\n", "\n"),
        )
        self.page.evaluate(
            "() => { navigator.clipboard.writeText = async () => { throw new Error('denied'); }; }"
        )
        self.page.get_by_role("button", name="Copy installation commands").click()
        self.page.wait_for_function(
            "document.querySelector('#copy-status').textContent.includes('copy them manually')"
        )
        self.assertEqual(
            self.page.locator("#install-command").inner_text(),
            self.page.evaluate("window.getSelection().toString()"),
        )

    def test_keyboard_navigation_and_reduced_motion(self) -> None:
        self.page.keyboard.press("Tab")
        self.assertEqual("Skip to content", self.page.locator(":focus").inner_text())
        self.assertGreaterEqual(self.page.locator(":focus").bounding_box()["y"], 0)
        self.assertNotEqual(
            "none",
            self.page.locator(":focus").evaluate(
                "el => getComputedStyle(el).outlineStyle"
            ),
        )
        self.page.keyboard.press("Enter")
        self.assertEqual("main", urlparse(self.page.url).fragment)
        self.page.emulate_media(reduced_motion="reduce")
        self.assertEqual(
            "auto",
            self.page.evaluate(
                "getComputedStyle(document.documentElement).scrollBehavior"
            ),
        )

    def test_links_and_local_assets(self) -> None:
        for href in self.page.locator("a[href]").evaluate_all(
            "links => links.map(a => a.getAttribute('href'))"
        ):
            if href == "#":
                continue
            if href.startswith("#"):
                self.assertEqual(1, self.page.locator(href).count(), href)
            elif href == REPO:
                continue
            else:
                self.assertTrue(href.startswith(f"{REPO}/blob/main/"), href)
                parsed = urlparse(href)
                relative = unquote(parsed.path.split("/blob/main/", 1)[1])
                path = (ROOT / relative).resolve()
                self.assertTrue(path.is_relative_to(ROOT))
                self.assertTrue(path.is_file(), href)
        for asset in ("styles.css", "app.js", "favicon.svg"):
            self.assertEqual(200, self.page.request.get(self.url + asset).status)

    def test_content_works_without_javascript(self) -> None:
        context = self.browser.new_context(java_script_enabled=False)
        try:
            page = context.new_page()
            page.goto(self.url)
            self.assertEqual(15, page.locator("[data-skill]:visible").count())
            self.assertTrue(page.locator("#install-command").is_visible())
            self.assertIn("-WhatIf", page.locator("#install-command").inner_text())
            self.assertFalse(page.locator("#copy-command").is_visible())
            self.assertFalse(page.locator("#catalog-toolbar").is_visible())
        finally:
            context.close()


if __name__ == "__main__":
    unittest.main(verbosity=2)
