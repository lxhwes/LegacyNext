# Fixtures

Captured client data only. Every file here comes from `/legacynext dump` pasted out of the
game, never from a shape we guessed at.

If a test needs a shape no fixture covers, write the test as `pending` and leave it. A
fabricated fixture is worse than a missing one: achievement IDs, category IDs, and criteria
will churn through beta, and Forever's API docs already differ from live retail 12.1.0 by
about 6k lines.

Name files after what produced them, e.g. `getachievementcriteriainfo_dungeons.lua`.
