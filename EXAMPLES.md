# Examples

Real-world code examples demonstrating the seven principles. Each example shows what LLMs commonly do wrong and how to fix it.

---

## 1. Think Before Coding

### Example 1: Hidden Assumptions

**User Request:** "Add a feature to export user data"

**❌ What LLMs Do (Wrong Assumptions)**

```python
def export_users(format='json'):
    """Export all users to a file."""
    users = User.query.all()
    
    if format == 'json':
        with open('users.json', 'w') as f:
            json.dump([u.to_dict() for u in users], f)
    elif format == 'csv':
        with open('users.csv', 'w') as f:
            writer = csv.DictWriter(f, fieldnames=['id', 'email', 'name'])
            writer.writeheader()
            writer.writerows([u.to_dict() for u in users])
    
    return f"Exported {len(users)} users"
```

**Problems:**
- Assumed it should export ALL users (what about pagination? privacy?)
- Assumed file location without asking
- Assumed which fields to include
- Assumed CSV fieldnames without checking actual data structure

**✅ What Should Happen (Surface Assumptions)**

```
Before implementing, I need to clarify:

1. **Scope**: Export all users or filtered subset? (privacy implications)
2. **Format**: You mentioned "export" - did you mean:
   - Download file in browser?
   - Background job with email notification?
   - API endpoint returning data?
3. **Fields**: Which user fields? (some might be sensitive)
4. **Volume**: How many users typically? (affects approach)

Simplest approach: Add an API endpoint that returns paginated JSON.
Would need more info for file-based exports.

What's your preference?
```

### Example 2: Codebase Contradicts Request

**User Request:** "Change the user model to use UUID instead of auto-increment ID"

**❌ What LLMs Do (Ignore Inconsistency)**

```python
# Silently changes User model, breaks 15 foreign key relationships
class User(Base):
    id = Column(UUID, primary_key=True, default=uuid4)
    # ... proceeds without mentioning downstream impact
```

**✅ What Should Happen (Flag the Inconsistency)**

```
Before changing User.id to UUID, I want to flag a potential issue:

The codebase currently uses integer foreign keys referencing User.id in:
- Order.user_id (integer FK)
- Comment.author_id (integer FK)
- Session.user_id (integer FK)
- 3 migration files assume integer IDs

Changing to UUID requires updating all of these.

Options:
- Option A: Full migration — change User.id + all FKs + write data migration. 
  Larger scope, but clean result.
- Option B: Add a separate uuid column, keep integer id as PK internally. 
  Minimal disruption, UUIDs exposed only in API.

Which approach do you prefer? Or should we scope this differently?
```

### Example 3: Multiple Interpretations with Tradeoffs

**User Request:** "Make the search faster"

**❌ What LLMs Do (Pick Silently)**

```python
@lru_cache(maxsize=1000)
async def search(query: str) -> List[Result]:
    # ... 200 lines of optimization code
```

**✅ What Should Happen (Present Tradeoffs)**

```
"Make the search faster" could mean different things:

Option A: Faster response time (add index + cache)
  → Optimizes for latency at the cost of memory usage
  → Estimated: 2 hours

Option B: Handle more concurrent searches (async + connection pool)
  → Optimizes for throughput at the cost of code complexity
  → Estimated: 4 hours

Option C: Faster perceived speed (progressive loading)
  → Optimizes for UX at the cost of additional frontend work
  → Estimated: 3 hours

Current search takes ~500ms for typical queries.
Which matters most here?
```

---

## 2. Be Direct, Not Sycophantic

### Example 1: User's Approach Has a Flaw

**User Request:** "Store user passwords in a JSON config file so admins can reset them easily"

**❌ What LLMs Do (Comply Silently)**

```python
# config/users.json
{
    "users": [
        {"username": "admin", "password": "admin123"},
        {"username": "alice", "password": "p@ssw0rd"}
    ]
}

def reset_password(username, new_password):
    config = load_json('config/users.json')
    for user in config['users']:
        if user['username'] == username:
            user['password'] = new_password
    save_json('config/users.json', config)
```

**✅ What Should Happen (Push Back)**

```
I'd push back on storing passwords in a JSON config file. This creates 
serious security issues:

- Passwords stored in plaintext (visible to anyone with file access)
- Config files often end up in version control
- No audit trail for password changes

For easy admin resets, I'd suggest:
- Store bcrypt-hashed passwords in the database (standard approach)
- Add an admin endpoint: POST /admin/reset-password
- This gives you the same ease of reset without the security risk

Should I implement the admin reset endpoint instead?
```

### Example 2: Giving Real Assessment

**User Request:** "I wrote this caching layer. Does it look good?"

```python
class SmartCache:
    def __init__(self):
        self.cache = {}
        self.hits = 0
        self.misses = 0
    
    def get(self, key):
        if key in self.cache:
            self.hits += 1
            return self.cache[key]
        self.misses += 1
        return None
    
    def set(self, key, value):
        self.cache[key] = value
```

**❌ What LLMs Do (Reassure)**

```
This looks great! Clean implementation with hit/miss tracking. 
The API is intuitive and the code is well-organized.
```

**✅ What Should Happen (Honest Assessment)**

```
A few concerns:

1. No eviction policy — this will grow unbounded and eventually OOM.
   At minimum, add a max_size with LRU eviction.

2. Not thread-safe — concurrent access will corrupt hits/misses 
   counters and the cache dict itself.

3. No TTL — stale data stays forever.

If this is for a single-threaded script with bounded data, it's fine 
as-is. If it's for a web server, these are real issues.

What's the use case? That determines which of these actually matter.
```

---

## 3. Simplicity First

### Example 1: Over-abstraction

**User Request:** "Add a function to calculate discount"

**❌ What LLMs Do (Overengineered)**

```python
from abc import ABC, abstractmethod
from dataclasses import dataclass

class DiscountStrategy(ABC):
    @abstractmethod
    def calculate(self, amount: float) -> float:
        pass

class PercentageDiscount(DiscountStrategy):
    def __init__(self, percentage: float):
        self.percentage = percentage
    def calculate(self, amount: float) -> float:
        return amount * (self.percentage / 100)

class FixedDiscount(DiscountStrategy):
    def __init__(self, fixed_amount: float):
        self.fixed_amount = fixed_amount
    def calculate(self, amount: float) -> float:
        return min(self.fixed_amount, amount)

@dataclass
class DiscountConfig:
    strategy: DiscountStrategy
    min_purchase: float = 0.0
    max_discount: float = float('inf')

class DiscountCalculator:
    def __init__(self, config: DiscountConfig):
        self.config = config
    def apply_discount(self, amount: float) -> float:
        if amount < self.config.min_purchase:
            return 0
        discount = self.config.strategy.calculate(amount)
        return min(discount, self.config.max_discount)
```

**Bloat patterns present:** Factory-style abstraction for single implementation, Config object with one meaningful field, Abstraction layer "for future extensibility."

**✅ What Should Happen (Simple)**

```python
def calculate_discount(amount: float, percent: float) -> float:
    """Calculate discount amount. percent should be 0-100."""
    return amount * (percent / 100)
```

**When to add complexity:** Only when you actually need multiple discount types. Refactor then.

### Example 2: Passthrough Wrapper

**User Request:** "Add logging to database operations"

**❌ What LLMs Do (Pointless Wrapper)**

```python
class DatabaseWrapper:
    def __init__(self, db):
        self.db = db
    
    def query(self, sql, params=None):
        logger.info(f"Query: {sql}")
        return self.db.query(sql, params)
    
    def execute(self, sql, params=None):
        logger.info(f"Execute: {sql}")
        return self.db.execute(sql, params)
    
    def commit(self):
        logger.info("Commit")
        return self.db.commit()
    
    # 10 more methods that just call self.db.method()
```

**✅ What Should Happen (Use existing mechanisms)**

```python
# Most ORMs/drivers already support this
logging.getLogger('sqlalchemy.engine').setLevel(logging.INFO)

# Or if truly custom logging is needed, a simple decorator:
def log_query(func):
    def wrapper(*args, **kwargs):
        logger.info(f"{func.__name__}: {args[1] if len(args) > 1 else ''}")
        return func(*args, **kwargs)
    return wrapper
```

---

## 4. Surgical Changes

### Example 1: Drive-by Refactoring

**User Request:** "Fix the bug where empty emails crash the validator"

**❌ What LLMs Do (Too Much)**

```diff
  def validate_user(user_data):
-     # Check email format
-     if not user_data.get('email'):
+     """Validate user data."""
+     email = user_data.get('email', '').strip()
+     
+     # Validate email
+     if not email:
          raise ValueError("Email required")
-     
-     # Basic email validation
-     if '@' not in user_data['email']:
+     if '@' not in email or '.' not in email.split('@')[1]:
          raise ValueError("Invalid email")
      
-     # Check username
-     if not user_data.get('username'):
+     # Validate username
+     username = user_data.get('username', '').strip()
+     if not username:
          raise ValueError("Username required")
+     if len(username) < 3:
+         raise ValueError("Username too short")
```

**Problems:** Added username validation nobody asked for, "improved" email validation beyond the fix, changed comments, added docstring.

**✅ What Should Happen (Surgical)**

```diff
  def validate_user(user_data):
      # Check email format
-     if not user_data.get('email'):
+     email = user_data.get('email', '')
+     if not email or not email.strip():
          raise ValueError("Email required")
      
      # Basic email validation
-     if '@' not in user_data['email']:
+     if '@' not in email:
          raise ValueError("Invalid email")
```

Only the lines that fix empty email handling. Nothing else.

### Example 2: Style Drift

**User Request:** "Add logging to the upload function"

**❌ What LLMs Do (Reformat Everything)**

```diff
- def upload_file(file_path, destination):
+ def upload_file(file_path: str, destination: str) -> bool:
+     """Upload file to destination with logging."""
      try:
-         with open(file_path, 'rb') as f:
+         with open(file_path, "rb") as f:
```

**Problems:** Changed quote style, added type hints, added docstring — none requested.

**✅ What Should Happen (Match Existing Style)**

```diff
+ import logging
+ logger = logging.getLogger(__name__)
+ 
  def upload_file(file_path, destination):
+     logger.info(f'Starting upload: {file_path}')
      try:
          with open(file_path, 'rb') as f:
```

Matched: Single quotes, no type hints, existing structure preserved.

---

## 5. Goal-Driven Execution

### Example 1: Vague vs. Verifiable

**User Request:** "Fix the authentication system"

**❌ What LLMs Do (Vague Approach)**

```
I'll fix the authentication system by:
1. Reviewing the code
2. Identifying issues
3. Making improvements
4. Testing the changes
```

**✅ What Should Happen (Verifiable Goals)**

```
To "fix authentication," I need to define success criteria.
What specific issue are we solving?

If the issue is "users stay logged in after password change":

Plan:
1. Write test: change password → verify old session invalidated
   → verify: test fails (reproduces bug)
2. Implement: invalidate sessions on password change
   → verify: test passes
3. Check edge cases: multiple sessions, concurrent changes
   → verify: additional tests pass
4. Verify no regression
   → verify: full test suite green

What's the specific auth issue you're seeing?
```

### Example 2: Test-First Verification

**User Request:** "The sorting breaks when there are duplicate scores"

**❌ What LLMs Do (Fix Without Reproducing)**

```python
def sort_scores(scores):
    return sorted(scores, key=lambda x: (-x['score'], x['name']))
```

**✅ What Should Happen (Reproduce First)**

```python
# 1. Write a test that reproduces the issue
def test_sort_with_duplicate_scores():
    scores = [
        {'name': 'Alice', 'score': 100},
        {'name': 'Bob', 'score': 100},
        {'name': 'Charlie', 'score': 90},
    ]
    result = sort_scores(scores)
    assert result[0]['name'] == 'Alice'  # deterministic order
    assert result[1]['name'] == 'Bob'
    assert result[2]['name'] == 'Charlie'

# Verify: test fails with inconsistent ordering

# 2. Now fix with stable sort
def sort_scores(scores):
    return sorted(scores, key=lambda x: (-x['score'], x['name']))

# Verify: test passes consistently
```

---

## 6. Know When to Stop

### Example 1: Spinning vs. Problem-Solving

**User Request:** "Fix the CSS so the sidebar doesn't overlap the main content on mobile"

**❌ What LLMs Do (Blind Persistence)**

```
Attempt 1: Changed sidebar to position: absolute → sidebar disappears on desktop
Attempt 2: Added media query with display:none → sidebar gone on mobile entirely
Attempt 3: Changed to flexbox → breaks the header layout
Attempt 4: Added z-index: 9999 → overlaps differently now
Attempt 5: Reverted and tried CSS Grid → same overlap issue
[continues for 15 more minutes...]
```

**✅ What Should Happen (Escalate After 3 Attempts)**

```
I've tried:
1. position: absolute with media query → sidebar disappears on desktop
2. Flexbox layout → breaks header, which depends on current grid structure
3. CSS Grid rearrangement → overlap persists, suggests the issue 
   isn't the sidebar CSS but the parent container's overflow behavior

My best guess: the parent container needs overflow: hidden or a 
defined width constraint, but I'm not confident I understand the 
full layout dependencies.

Could you share which breakpoint this happens at, or point me to 
the parent layout component?
```

### Example 2: Fix Creates More Problems

**User Request:** "Fix the memory leak in the WebSocket handler"

**❌ What LLMs Do (Keep Patching)**

```
Fix 1: Added cleanup on disconnect → now connections drop randomly
Fix 2: Added reconnect logic → now duplicate messages appear
Fix 3: Added dedup check → now messages are delayed by 500ms
Fix 4: Reduced dedup timeout → back to duplicates...
```

**✅ What Should Happen (Step Back)**

```
I've been patching symptoms rather than root-causing this.

My first fix (cleanup on disconnect) caused random drops, which 
suggests the cleanup is too aggressive — it's closing connections 
that are still alive.

Before adding more patches: I think we need to understand why 
connections aren't being cleaned up in the first place. Can you 
share how connections are registered? The leak likely starts there, 
not in the disconnect handler.
```

---

## 7. Pre-Submit Review

### Example: Catching Your Own Mistakes

**User Request:** "Add pagination to the /users endpoint"

Before presenting the changes, the LLM should self-check:

```
Pre-submit review:
✅ Assumptions stated: assumed offset-based pagination (not cursor-based), 
   default page_size=20. Mentioned this in the plan.
✅ Tests: Added test for page 1, page 2, empty page, and invalid page param.
✅ Scope: Only touched users_controller.py and test_users.py. 
   No changes to unrelated files.
```

**❌ What gets caught by this step:**

- "I assumed cursor-based pagination but never told the user" → state it now
- "I didn't write tests because it seemed simple" → add them or explain why not
- "I also refactored the auth middleware while I was in there" → revert that

---

## Anti-Patterns Summary

| Principle | Anti-Pattern | Fix |
|-----------|-------------|-----|
| Think Before Coding | Silently assumes format, fields, scope | List assumptions, ask for clarification |
| Be Direct | "Looks great!" when there are issues | Give honest assessment with specifics |
| Simplicity First | Strategy pattern for single calculation | One function until complexity is needed |
| Surgical Changes | Reformats quotes, adds types while fixing bug | Only change lines for the reported issue |
| Goal-Driven | "I'll review and improve the code" | "Write test for X → make it pass → verify" |
| Know When to Stop | 5+ attempts at CSS without pausing | Summarize 3 failures, ask for direction |
| Pre-Submit Review | Ship without checking own assumptions | Verify assumptions stated, tests exist |

## Key Insight

The "overcomplicated" examples aren't obviously wrong — they follow design patterns and best practices. The problem is **timing**: they add complexity before it's needed, which makes code harder to understand, introduces more bugs, takes longer to implement, and is harder to test.

**Good code solves today's problem simply, not tomorrow's problem prematurely.**
