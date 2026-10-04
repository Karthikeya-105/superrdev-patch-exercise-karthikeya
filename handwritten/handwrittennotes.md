1. SQL Operator Precedence
File: TaskRepository.java
What: Search returned archived tasks and ignored the status filter for title matches.
Why: AND binds tighter than OR in SQL. Without parentheses, archived = FALSE and the status filter only applied to one branch.
Fix: Wrapped both LIKE conditions in parentheses. Also added id DESC as tiebreaker for stable pagination.
Verified: ?q=api no longer returns the two archived tasks.

2. Artificial Thread.sleep
File: TaskController.java
What: Every search request slept up to 1000 ms. Shorter query = longer delay.
Why: Fake "complexity estimation" logic that called Thread.sleep on the request thread. Blocked the servlet thread for no reason.
Fix: Deleted the block entirely.
Verified: Response time dropped from ~1000 ms to under 200 ms.

3. Invalid Status → 500
File: TaskController.java
What: ?status=FOO crashed with a 500 stack trace instead of a clean 400.
Why: TaskStatus.valueOf() throws IllegalArgumentException on unknown values. No try/catch, no global handler.
Fix: Wrapped in try/catch, returned 400 Bad Request with a JSON error.
Verified: ?status=FOO now returns 400 with {"error": "Invalid status: FOO"}.

4. Unsafe Pagination Bounds
File: TaskController.java
What: ?page=0 or ?pageSize=-5 threw IndexOutOfBoundsException (500). ?pageSize=10000000 returned a huge list.
Why: No validation on inputs; subList with negative indices fails; pageSize was unbounded.
Fix: Reject page < 1 / pageSize < 1 with 400. Cap pageSize at 100. Used long math to avoid overflow.
Verified: Bad inputs return 400; pageSize=10000000 is capped at 100.

5. No Debounce on Search
Files: SearchBar.jsx → App.jsx → useTasks.js
What: Typing "api" fired 3 API calls. Combined with Bug 2, the UI felt frozen.
Why: onChange updated state immediately; the useEffect in useTasks depended on query; every keystroke triggered a fetch.
Fix: Created useDebouncedValue.js hook (300 ms). App.jsx passes the debounced query to useTasks.
Verified: DevTools Network shows one request after typing stops, not three.

6. Page Not Reset on Filter Change
File: App.jsx
What: On page 3, changing the status filter showed "No tasks found." even though results existed. Pagination disappeared.
Why: setQuery and setStatus didn't reset page. Stale page number sent to the backend.
Fix: Wrapped handlers to setPage(1) when query or status changes.
Verified: Changing filters resets to page 1 and shows results.

7. Stuck error / loading in useTasks
File: useTasks.js
What: One failed request broke the UI permanently. Error never cleared; loading stayed true forever.
Why: .then didn't clear error; .catch didn't set loading to false. Asymmetric state handling.
Fix: Rewrote the effect — clear error at start, use .finally to clear loading, added cancelled flag to ignore stale responses.
Verified: Stop backend → error shows. Restart → recovery works.

8. Race Condition on Fast Typing
File: useTasks.js
What: Old, slow responses overwrote newer results. Table briefly showed data from an earlier query.
Why: No cancellation. Every query change fired a fetch; out-of-order responses applied state unpredictably.
Fix: Added let cancelled = false in the effect. Each promise callback checks if (cancelled) return;. Cleanup sets cancelled = true.
Verified: Fast typing + filter changes always show correct final results.

9. TaskTable Hides Errors Behind Loading
File: TaskTable.jsx
What: When both loading and error were true, the user saw "Loading tasks…" forever and never the error.
Why: if (loading) was checked before if (error).
Fix: Swapped the order — check error first.
Verified: With backend down, error renders immediately, not a spinner.

10. Oracle PL/SQL — Same Bug + Oracle-Specific Issues
File: db/oracle/task_search_package.sql
What: (a) Same precedence bug as the repository. (b) "No filter" returned zero rows. (c) Lowercase status returned nothing.
Why:

(a) Missing parentheses around the OR.

(b) In Oracle, '' is NULL, so '%' || NULL || '%' = NULL, and LIKE NULL matches nothing.

(c) Oracle is case-sensitive; status = p_status failed for lowercase input.
Fix:

Parenthesized the OR in both COUNT(*) and cursor queries.

Built v_term with explicit IF p_search_term IS NULL OR TRIM(...) IS NULL THEN v_term := '%'; END IF;

Compared status = UPPER(TRIM(p_status)).

Added id DESC to ORDER BY.
Verified by inspection — the Oracle file doesn't run locally