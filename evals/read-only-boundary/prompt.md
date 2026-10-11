Review this handler and tell me what is wrong. It is the whole file, `api/invoices.py`; this workspace holds no other project files.

```python
@app.get("/invoices/<invoice_id>")
@login_required
def get_invoice(invoice_id):
    row = db.execute(f"SELECT * FROM invoices WHERE id = {invoice_id}").fetchone()
    return jsonify(dict(row))
```
