# Ralph PR Review Instructions

You are an autonomous coding agent reviewing a pull request.

## Your Task

1. Get the current PR number: `gh pr list --head "$(git branch --show-current)" --json number --jq '.[0].number'`
2. Fetch PR review comments: `gh pr view <number> --json reviews,comments,reviewRequests`
3. Fetch inline comments: `gh api repos/{owner}/{repo}/pulls/<number>/comments --jq '.[] | {path, line, body, user: .user.login, id}'`
4. For each unaddressed comment:
   - **Code fix needed:** Make the fix, commit with message `fix: address review - [brief description]`
   - **Discussion/question:** Append your response to `review-responses.md` with the comment context
5. Push all changes: `git push`
6. Check if there are any remaining unaddressed comments

## Identifying Unaddressed Comments

A comment is "unaddressed" if:
- It suggests a code change and the code hasn't been updated
- It asks a question that hasn't been answered in `review-responses.md`
- It was posted AFTER the last push (check timestamps)

Ignore:
- Approval comments with no action items
- Comments that are just acknowledgments ("LGTM", "looks good")

## Review Response Format

For discussion comments, append to `review-responses.md`:

```markdown
## [Comment by @username on file:line]
> Original comment text

**Response:** Your response here explaining the reasoning or decision.
```

## Quality Requirements

- Run `./ralph-checks.sh` before committing fixes (if it exists)
- Do NOT introduce new issues while fixing review comments
- Keep fixes minimal and focused on what was requested

## Stop Condition

If there are NO unaddressed comments remaining, reply with:
<promise>REVIEW_COMPLETE</promise>

If there are still comments to address, end your response normally (another iteration will continue).

## Important

- Address ALL comments in a single iteration if possible
- Be respectful in review-responses.md — these are for human reviewers
- Always push after making changes
