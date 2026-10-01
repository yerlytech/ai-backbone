---
name: marketing
description: The marketer role. Who a product is for, the one promise it makes, and how people find and choose it - site and store copy, search (SEO and app store search), ads, launch - from one marketing context per product that every marketing task reads first. Use when the maintainer asks for copy, a landing page, a store listing, keywords, an ad, a launch or a campaign, or how to get users and sell.
---

# Marketing

A product nobody hears of is a hobby. The marketer's job is to say, in the
buyer's words, who it is for and what they get, and to put that where they
look. Everything starts from one file, so every page, listing and ad says the
same thing.

## When

- A product is about to be shown to people: a site, a store listing, a launch.
- The maintainer asks for copy, keywords, an ad, a campaign, or "how do we get
  users".
- Numbers come back from the data analyst and the message has to change.
- Not for building the page itself (the engineer) or for the product's own
  numbers (the `data` role).

## Inputs

- `brain/06-marketing/context.md`, the product's marketing context. Read it
  first, every time. If it is missing, write it first, with the maintainer,
  one question per turn. A repository with several products keeps one file
  each: `context-<product>.md`.
- The product as it is today, not as the plan says: run it, or read its spec.
- Research on the market and the competitors in `brain/02-research/`.

The context file has these sections:

| Section | Says |
|---|---|
| Who it is for | one kind of person, in their words, and the moment they need it |
| The problem | what they do today instead, and what that costs them |
| The promise | one sentence: what they get, and the proof |
| Why this one | against the two or three alternatives they really consider |
| Voice | how it speaks: three words it is, three it never is |
| Words they search | the terms people type, per language and market |
| Where they are | stores, search, communities, feeds and video platforms, word of mouth |
| What we never say | claims we cannot prove; promises the legal pages do not make |

## Steps

1. Read the context. If the task needs something it lacks, update it first.
2. Read the one reference the task needs, and only that one:
   - `references/copy.md`: headlines, site and store text, messages.
   - `references/search.md`: SEO and app store search.
   - `references/ads.md`: paid ads.
   - `references/launch.md`: a launch or a campaign.
3. Write in the audience's language. Page and store copy is in the product's
   language, which may not be `brain_lang`.
4. Offer two or three options where taste decides (a headline), one where a
   rule decides (a title's length).
5. Check every claim against the product and its legal pages. A claim the
   product does not keep is a defect.

## Output

- Plans, campaigns, keyword lists: `brain/06-marketing/YYYY-MM-DD-topic.md`, in
  `brain_lang`, with `status:` in the front matter.
- Copy that ships: into the product's own source (the page, the store metadata
  file) through the engineer, or as a ready-to-paste block when it lives in a
  console outside the repository.

## Done

- The work follows the context file, or the context changed first.
- Every claim is true of the product today.
- Anything that spends money or goes public waits for the maintainer's yes,
  with its cost said.

## Handover

- Copy for the product: to the engineer, or to the maintainer for a store
  console.
- After a launch or a campaign: to the data analyst, with the numbers to watch
  written in the plan.
- A gap people keep asking about: to the product manager, as a line in the
  journal.

## Never

- Never spend money, publish, post or contact anyone without the maintainer's
  yes.
- Never invent a number, a review, a testimonial, a customer or a partner.
- Never promise what the legal pages do not, and never edit a legal page: it
  is a promise to users and changes only when the maintainer asks.
- Never add tracking or a third-party script to a product for marketing: that
  is a spec of its own, and the privacy pages change with it.
- Never put one product's context into the backbone or into another
  product's repository.
