# Code Guidelines

**Python Version:** 3.13+

# Inspect Tasks

If we are doing inspect-ai tasks, make sure that you refer to the included inspect-ai source code and docs. If it isn't there, clone it into the repo as a directory and add it to the gitignore. 

If we are making an inspect-ai task and you need to look at an eval log (the result of an agent run on the inspect task), you can do so using inspect log dump --json, or possibly even better, directly using the API that the inspect viewer frontend uses. You should especially be looking for errors. 


## Code Quality Standards

- No code duplication; type hints everywhere; `ruff format` (line length 100); `ruff check` for linting.
- Concise one-line docstrings preferred; comments explain WHY not WHAT.
- Private functions use leading underscore; import modules not functions (Google style).
- No circular dependencies; higher-level modules depend on lower-level.

## Linting/Type Config 

- NEVER modify linting/type rules in `pyproject.toml` without explicit permission.
- No `# type: ignore` without justification; fix code, don't silence checkers.

## Python 3.13+ Type Hints 

- Constructor syntax for empty collections: `list[int]()` not `: list[int] = []`
- Simplified Generator: `Generator[int]` not `Generator[int, None, None]`
- Use `Callable` instead of `Any` for callables; `Any` only as last resort (dynamic introspection, JSON parsing, testing).
- Use `TypeVar` for type-preserving decorators (preserves exact function signature).
- Use `Callable[..., Any]` for function params, not bare `Any`.
- Document why when using `Any`.

## TypedDict Usage 

**Why TypedDict over dataclasses/namedtuples:** TypedDict has zero runtime overhead (it's just a `dict`), native JSON serialization without conversion, and no boundary translation needed when parsing config files or API responses. Dataclasses require `asdict()` for JSON; namedtuples serialize as arrays, not objects. For structured data that flows to/from JSON, TypedDict avoids conversion overhead entirely.

**Never use `.get()` on TypedDicts.** TypedDicts have known keys at type-check time—use direct key access.
TypedDicts with `total=False` or `NotRequired` fields may have optional fields, in which case you should
use `if "key" in dict: ...` to check for the key and then use `dict["key"]` to access the value.

**Always use constructor syntax when creating TypedDicts**—not dict literals. This provides type validation at the call site and makes the code self-documenting. Applies everywhere: return statements, assignments, function arguments, and tests.

```python
class ChangeCheckResult(TypedDict):
    changed: bool
    reason: str

# Good - constructor syntax (type-checked)
return ChangeCheckResult(changed=True, reason="code changed")
result = ChangeCheckResult(changed=False, reason="")
some_function(ChangeCheckResult(changed=True, reason="test"))

# Bad - dict literal (no type validation, missing fields not caught)
return {"changed": True, "reason": "code changed"}
result = {"changed": False}  # Missing 'reason' not caught!
```

## Import Style (Google Python Style Guide)

- Import modules, not functions: `from pivot import fingerprint` then `fingerprint.get_stage_fingerprint(...)`.
- No relative imports; no `sys.path` modifications.
- **This applies to all packages including third-party**—use `import pydantic` then `pydantic.BaseModel`, not `from pydantic import BaseModel`.
- No exceptions for stdlib—use `import pathlib` then `pathlib.Path`, not `from pathlib import Path`.
- Exception: type hints in `TYPE_CHECKING` blocks may import types directly.
- Exception: types from `pivot.types` may be imported directly: `from pivot.types import StageStatus, StageResult`.

```python
# Good
from pivot import fingerprint
from pivot.types import StageStatus, StageResult
import pathlib
import pydantic

fp = fingerprint.get_stage_fingerprint(func)
path = pathlib.Path("/some/path")
status = StageStatus.READY

class MyParams(pydantic.BaseModel):
    learning_rate: float = 0.01

# Bad
from pivot.fingerprint import get_stage_fingerprint
from pathlib import Path
from pydantic import BaseModel

fp = get_stage_fingerprint(func)  # Where is this from?
path = Path("/some/path")  # Where is Path from?

class MyParams(BaseModel):  # Where is BaseModel from?
    learning_rate: float = 0.01
```

## No `__all__` Declarations

- Don't use `__all__` in modules—it's unnecessary maintenance overhead.
- Use underscore prefix (`_helper`) to indicate private functions.
- For package `__init__.py` re-exports, use explicit re-export syntax: `from module import X as X`.

## No Tiny Wrapper Functions

**Never create 1-2 line functions that just wrap a third-party library call—call the library directly.**

## Docstrings

**No module-level docstrings.** Don't add docstrings at the top of Python files unless explicitly asked.

**Simple functions (<20 lines) get one-line docstrings. Period.**

Skip Args/Returns/Examples if type hints make it obvious. Don't repeat what the function signature already says.

```python
# Bad - verbose, repeats type hints
def resolve_path(path: str) -> pathlib.Path:
    """Resolve path relative to project root (or use absolute).

    Args:
        path: File path (relative or absolute)

    Returns:
        Resolved absolute path
    """

# Good - concise, says what it does
def resolve_path(path: str) -> pathlib.Path:
    """Resolve relative path from project root; absolute paths unchanged."""

# Bad - explains obvious behavior
def get_project_root() -> pathlib.Path:
    """Get the project root directory.

    Returns the cached project root if available, otherwise finds it
    by calling find_project_root() and caches the result.

    Returns:
        Path: The project root directory path
    """

# Good - concise
def get_project_root() -> pathlib.Path:
    """Get project root (cached after first call)."""
```

## Comments - Code Clarity Over Comments

**Prefer improving code clarity over leaving comments. Comments are a last resort.**

Before adding a comment, ask: "Can I make this code self-explanatory instead?" Better variable names, smaller functions, and clearer structure beat comments every time.

**When to add comments (rare):**

- Non-obvious WHY that can't be expressed in code
- Important timing/ordering constraints
- Known limitations or edge cases
- Complex algorithm steps that can't be simplified

**When NOT to add comments (common):**

- Obvious WHAT the code does (e.g., "Add node to graph" before `graph.add_node()`)
- Step-by-step descriptions (e.g., "Step 1:", "Step 2:", "Check if ready")
- Redundant with function/variable names (e.g., "Build output map" before `_build_outputs_map()`)
- Information already in docstrings
- Anything the code already expresses clearly

```python
# Good - explains non-obvious WHY
# Validate paths BEFORE normalizing (check ".." on original paths)
_validate_stage_registration(stages, name, deps, outs)

# Bad - states obvious WHAT
# Add all stages as nodes
for stage in stages:
    graph.add_node(stage)

# Good - clarifies intent
# Reverse chain to get correct order (module.sub.attr)
attr_path = ".".join(reversed(chain))

# Bad - redundant with code
# Parse source code to AST
tree = ast.parse(source)
```

**Rule of thumb:** If removing the comment makes the code unclear, try to write clearer code instead (helper functions, variable names). If that doesn't work, keep the comment.

**Write evergreen documentation:** Avoid time-relative language like "recently added", "new feature", "will be removed soon", or "as of version X". Future readers won't know when "recently" was. Instead, state facts that remain true regardless of when the documentation is read.

## Early Returns (Reduce Nesting)

- Use early `return`/`continue` to keep main logic at top indentation level.
- Avoid pyramid of doom; each guard clause should be simple, independent.

## Match Statements (Prefer Over if/elif Chains)

Use `match` statements instead of `if`/`elif` chains when dispatching on enum values, type discrimination, or multiple conditions on the same variable.

```python
# Good - match statement
match change["change_type"]:
    case ChangeType.ADDED:
        row_data.append(f"[green]{new_val}[/]")
    case ChangeType.REMOVED:
        row_data.append(f"[red]{old_val}[/]")
    case _ if old_val != new_val:
        row_data.append(f"[yellow]{old_val} -> {new_val}[/]")
    case _:
        row_data.append(str(new_val) if new_val is not None else "")

# Bad - if/elif chain for type dispatch
if change["change_type"] == ChangeType.ADDED:
    row_data.append(f"[green]{new_val}[/]")
elif change["change_type"] == ChangeType.REMOVED:
    row_data.append(f"[red]{old_val}[/]")
elif old_val != new_val:
    row_data.append(f"[yellow]{old_val} -> {new_val}[/]")
else:
    row_data.append(str(new_val) if new_val is not None else "")
```

**When to use match:** Enum dispatch, type discrimination, structured pattern matching, multiple conditions on one variable.

**When if/elif is fine:** Simple boolean conditions, early returns/guards, conditions on different variables.

## Private Functions

- Use `_prefix` for module-internal helpers; public = used by other modules.

## Error Handling

```python
# Good - specific exception
class FingerprintError(Exception): pass

# Bad - generic
raise Exception("failed")
```

## Input Validation Over Defensive Programming

Prioritize validating inputs at boundaries rather than defensively handling every possible error deep in the code.

**Principles:**

- Validate inputs early, then trust them downstream
- Fail fast with clear errors rather than silently degrading
- Don't try to "fix" invalid inputs—reject them
- Avoid excessive try/catch that masks bugs

```python
# Good - validate input, then operate confidently
def export_stages(stages: list[str]) -> None:
    missing = [s for s in stages if s not in REGISTRY]
    if missing:
        raise ExportError(f"Stages not found: {missing}")

    for stage in stages:
        _export_stage(REGISTRY[stage])  # Known to exist

# Bad - defensive checks everywhere
def export_stages(stages: list[str]) -> None:
    for stage in stages:
        if stage in REGISTRY:  # Silent skip
            try:
                _export_stage(REGISTRY.get(stage, {}))
            except Exception:
                pass  # Silent failure
```

**When defensive code IS appropriate:**

- External I/O (network, filesystem, user input)
- Third-party library calls with unclear error modes
- Graceful degradation in non-critical paths

## Logging

```python
# Good
logger.info(f"Stage {name} completed in {duration:.2f}s")

# Bad
print(f"Stage {name} completed")
```

## Development Commands

```bash
uv sync --active       # Install dependencies
pytest tests/ -n auto  # Run tests (parallel)
ruff format .          # Format
ruff check .           # Lint
basedpyright .         # Type check
```

## After Completing a Feature

- Update the **Development Roadmap** in `README.md` to reflect completed work
- Document any new **user-facing functionality** in the appropriate README section (CLI commands, API changes, new features)
- Keep the roadmap concise—use single-line summaries, not granular checklists

## Critical Discoveries

1. Test helpers must be module-level, not inline—`getclosurevars()` doesn't see module imports in inline closures.
2. Helper functions starting with single underscore (`_helper`) ARE tracked. Only dunder names (`__name__`, `__file__`, etc.) are filtered.
3. Use assertion messages instead of inline comments—messages appear in failure output.
4. **Circular import resolution:** When two modules have bidirectional dependencies, extract shared types/exceptions to a separate module (e.g., `exceptions.py` breaks `registry.py` ↔ `trie.py` cycle).


# Note

Thank you Claude for your help!