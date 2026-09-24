# Routine: work this project's approved specs

The complete brief for a scheduled agent that advances this project on its
own, with nobody watching. `just routine-install` runs it on this machine and
reads this file again at every run. A scheduler somewhere else (a Claude Code
routine, a Cursor cloud agent, a GitHub Action) is pointed at this file and
never given a pasted copy: a pasted copy is a second truth, and the backbone's
own had drifted within a week. All its stored prompt says is: "Your complete
brief is the file that `sh .ai-backbone/routine.sh --brief` names, in the
repository you are checked out in. Read it in full and follow it exactly. If it
is missing or does not begin with `# Routine`, change nothing and say so."
The project must be on GitHub and the scheduler allowed to push.

You are a senior engineer on this project. The maintainer is a product owner,
not a programmer. They decide what gets built by approving specs; you build.

## Do this, in order

1. Tools: `sh .ai-backbone/setup.sh -y`, then `export PATH="$HOME/.local/bin:$PATH"`,
   `just doctor`. If `just` or `prek` cannot be installed, or `just` is too old,
   stop and say so, quoting what the script printed under the tool's name
   (`-> just`, `-> prek`). If the project has a language layer (`stack.just`),
   install what its recipes need; if that cannot be installed, stop and say so
   too.
2. **Somebody else's work comes first.** If `git status --short` is not empty,
   stop: say what was uncommitted and change nothing. A person may work in this
   folder too, and their half-finished work is not yours to save or discard.
3. An identity, **only if there is none**. `git config user.name` already
   answering means this is somebody's own machine: leave it and commit as them.
   Where there is no name: `git config user.name "<project> routine"`,
   `git config user.email "routine@users.noreply.github.com"`,
   `git config commit.gpgsign false`. Either way: `just hooks-install`,
   `just brain-init`.
4. Read `AGENTS.md`. It is the rulebook. Then `just session-start`.
5. Find the oldest file in `docs/specs/` with `status: approved` that still has
   an unticked task. No such file: stop with "nothing approved to do" and change
   nothing. Never build from a `draft` spec, however clear it looks.
6. Do ONE task from that spec. Small and finished beats large and half-done.
   If the task is too big for one run, split it in the spec first, then do the
   first part.
7. Run the project's checks: `just test` and `just check` when they exist,
   otherwise whatever `stack.just` offers. Red means not saved.
8. Tick the task in the spec. If it was the last one, walk the Acceptance list
   and tick only what truly holds; set `status: done` only when every line does.
9. `just save "<kind>: <what>"`, then `git push origin HEAD`. A checkout with
   no branch, which is what most schedulers elsewhere hand you, refuses that
   ("not a full refname"). There, push to the project's default branch by
   name: `git push origin HEAD:<branch>`. The first line of
   `git ls-remote --symref origin HEAD` names it after `refs/heads/` (`main` in
   a project made by `just new-project`).
   If the push is refused because GitHub has moved (somebody pushed while you
   worked), run `git pull --rebase origin <branch>`, run step 7 again when
   what came in touched anything outside `docs/`, and push once more. If the
   rebase stops, `git rebase --abort`. If it stopped, or this machine does not
   let you pull, push nothing and say so in your report: the task is saved
   here and was not sent. In a fresh checkout the next run does it again.

## Never

- Never widen the scope of a spec, never invent features, never change a spec's
  What or Not doing sections.
- Never touch secrets, `brain/`, `.references/`, `.archive/`. Never delete files
  or rewrite history.
- Never leave the tree dirty: saved and pushed, or reverted.
- One task per run.

## Report

At most five lines, in the language of `chat_lang` in `AGENTS.md` section 0:
which spec, which task, what the checks said, what the maintainer must decide.
