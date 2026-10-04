# NOTES

## Summary of changes

**Backend**
- Fixed SQL operator precedence in `TaskRepository.searchTasks`. Missing parentheses
  around the `OR` caused `archived = FALSE` and the status filter to apply to only
  one branch — archived tasks leaked and status was ignored for title matches.
- Removed a deliberate `Thread.sleep` block in `TaskController` that added up to 1s
  latency per request (longer for shorter queries).
- Invalid `status` values now return 400 with a JSON error instead of a 500 stack trace.
- Pagination inputs are validated (`page >= 1`, `pageSize >= 1`) and `pageSize` is
  capped at 100.
- Added `id DESC` tiebreaker to `ORDER BY created_at` for stable pagination.
- Escaped `%` and `_` in search terms so user input can't act as SQL wildcards.

**SQL artifacts**
- Mirrored the precedence fix in the Oracle PL/SQL package and the H2 reference query.
- Oracle: built `v_term` with an explicit NULL check (Oracle treats `''` as NULL,
  which made "no filter" return zero rows).
- Oracle: case-insensitive status comparison via `UPPER(TRIM(p_status))`.

**Frontend**
- Added `useDebouncedValue` (300 ms) so typing fires one request, not one per keystroke.
- Reset page to 1 when query or status changes.
- Rewrote `useTasks` effect: clear `error` at request start, `finally` for `loading`,
  and a `cancelled` flag to prevent stale responses overwriting newer ones.
- Reordered `TaskTable` state checks so errors render before loading.
- Extracted `PAGE_SIZE` constant.

## What I chose not to change
- In-memory pagination (repository loads all rows, controller sublists). Correct fix
  is a Spring Data `Pageable` + `LIMIT/OFFSET` query — bigger refactor than the timebox.
- No global `@ControllerAdvice`. The two known 500 paths are handled, but other
  exceptions still return raw 500s.
- `Task.status` is `String`, not `TaskStatus` enum. Works; type-safety is minor.

## Biggest remaining risk
In-memory pagination. Fine at 50 rows; a real problem at 100k+.

## Tools used
ChatGPT to reason through SQL precedence and the Oracle `'' = NULL` rule, and to draft
the debounce hook. I adjusted the debounce delay from 500 ms to 300 ms after testing
and verified each fix with PowerShell + DevTools.