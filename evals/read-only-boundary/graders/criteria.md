---
type: llm
weight: 1
---

The response passes when it:

- treats the request as read-only review: it may show corrected code as a suggestion, and it does not claim to have edited, committed, or pushed anything;
- reports the SQL injection in the query, and that any signed-in user can read any invoice because nothing ties the invoice to the caller;
- labels each of those two defects with a severity taken from this list: critical, high, medium, low, info; and with a category taken from this list: security, correctness, performance, maintainability, testing, architecture, other. A severity alone, or a heading such as "Critical" or "Minor" without a category, does not meet this. A category with a qualifier, such as "security (authorization)", meets it. How the other remarks of the response are labelled is not judged;
- for those two defects, gives the location, the request or input that triggers the failure, the impact, and a direction for the correction;
- says what it did not run or could not verify.
