# Search

Being found by people already looking: web search (SEO) and app store search
(ASO). Free, slow, and it compounds.

## Words first

Build the list before writing any page or listing, and keep it in the context
file's "Words they search", per language and market.

- Sources that need no paid tool: the search box's suggestions, "people also
  ask", the titles of the pages and apps that rank today, the store's own
  search suggestions, the words people use in reviews and forums.
- Group the words by intent: **know** (what is X), **compare** (X vs Y, best X
  for Z), **do** (download X, book X near me). A page answers one intent.
- Prefer the words a small product can win: specific, local, in its own
  language, over the one big word every competitor wants.

## A web page

| Part | Rule |
|---|---|
| Title tag | the main words first, then the name; about 60 characters is what is shown |
| Meta description | the promise and the call to action; about 155 characters is shown |
| One `h1` | says what the page is, close to the title |
| Address | short, words not ids, one language per path (`/tr/…`, `/en/…`) |
| Body | answers the intent fully; headings people would scan for |
| Images | descriptive file names and `alt` text |
| Links | related pages link to each other with words, not "click here" |
| Speed and phone | fast on a phone over a mobile network; nothing loaded from elsewhere that is not needed |

The site as a whole: a `sitemap.xml` and a `robots.txt`; `hreflang` when a
page exists in several languages; structured data (schema.org) only where it
describes the page truly (an organisation, an app, a local business). Search
Console needs the maintainer's account: ask before setting it up.

## A store listing

Each store indexes different fields, and the limits change: read the store's
own current documentation before relying on one. As last checked:

| Store | Indexed fields | Limits (characters) |
|---|---|---|
| App Store | name, subtitle, keyword field | name 30, subtitle 30, keywords 100, comma-separated |
| Google Play | title, short and full description | title 30, short 80, full 4000 |

- App Store: do not repeat a word across the name, subtitle and keyword field;
  each word counts once. No spaces after commas, no competitor names.
- Google Play: the full description is read for search; use the main words
  naturally, a few times, never as a list.
- Ratings, recent updates and the share of people who install after seeing the
  listing move the ranking as much as the words do.
- Each market (country and language) has its own listing: localise it.

## Checking

Look at it again a month later, not a day later: the rank for the main words,
the people who came from search, the share who installed or signed up. The
data analyst reads those numbers.
