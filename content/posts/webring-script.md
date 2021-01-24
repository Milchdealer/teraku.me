+++ 
draft = false
date = 2020-08-30T11:36:41+02:00
title = "Connecting my RSS reader to my blog's webring"
description = "How to automatically export my RSS feeds to webring"
slug = "blog-setup-deployment" 
tags = ["blog", "openring", "webring", "rss"]
categories = ["blog"]
externalLink = ""
series = []
+++
# Outline
Since I am using [`openring`](https://sr.ht/~sircmpwn/openring/), I will detail how I automatically update the posts in the webring for this blog with the feeds from the blogs I follow.

# My RSS feed / `news-flash`
## Finding the stored feed data
I'm using the RSS reader [`news-flash`](https://gitlab.com/news-flash/news_flash_gtk).
So the first order of business was finding out where where and how my feed was stored.
Since `news-flash` is FOSS, a quick into the sourcecode revealed the following.
```rust
lazy_static! {
    pub static ref CONFIG_DIR: PathBuf = glib::get_user_config_dir()
        .expect("Failed to find the config dir")
        .join("news-flash");
    pub static ref DATA_DIR: PathBuf = glib::get_user_data_dir()
        .expect("Failed to find the data dir")
        .join("news-flash");
}
```

And `glib` is refering to the GTK+ library for rust.
Gnome uses the [XDG Base Directory Specification](https://developer.gnome.org/basedir-spec/), which tells us how data and config directories are to be defined.
With this knowledge equipped, I found the folder, and in it resides a SQLite database file.

> It actually was a little more complicated than that. I am using Pop!OS (currently contemplating a migration to nixOS) which does not set `XDG_DATA_HOME`, but I found it in my home folder's `.var/` folder.

## Identifying the data location
Next up was finding out what to take out of the database.
For openring to work, links to the RSS feeds of the respective sites are needed.
Let's take a look inside the database.
```sh
$ sqlite3 
SQLite version 3.33.0 2020-08-14 13:23:32
Enter ".help" for usage hints.
Connected to a transient in-memory database.
Use ".open FILENAME" to reopen on a persistent database.
sqlite> .open database.sqlite
sqlite> .tables
__diesel_schema_migrations  fts_table                 
articles                    fts_table_docsize         
categories                  fts_table_segdir          
enclosures                  fts_table_segments        
fav_icons                   fts_table_stat            
feed_mapping                taggings                  
feeds                       tags
```

So to find our feeds, the logical conclusion would be to look sinde the `feeds` table.
```sh
sqlite> .schema feeds
CREATE TABLE feeds (
	feed_id TEXT PRIMARY KEY NOT NULL,
	label VARCHAR NOT NULL,
	website TEXT,
	feed_url TEXT,
	icon_url TEXT,
	sort_index INTEGER
)
```

Bingo!
Next, I want to only export feeds from blogs that I directly want to link upon, since it's a quasi endorsement and also webrings are about distribution and decentralisation, so no need to link to hackernews.
For that I created a category called `blog-export`.
The `categories` table looks as follows.
```sh
sqlite> .schema categories
CREATE TABLE categories (
	category_id TEXT PRIMARY KEY NOT NULL,
	label TEXT NOT NULL,
	parent_id TEXT NOT NULL,
	sort_index INTEGER
, category_type INTEGER NOT NULL default 0);
CREATE TRIGGER on_delete_category_trigger
	AFTER DELETE ON categories
	BEGIN
		DELETE FROM feed_mapping WHERE feed_mapping.category_id=OLD.category_id;
	END;
```

Lastly, how do we connect a category to a feed?
My first bet was the `feed_mapping` table, and I was right.
```sh
sqlite> .schema feed_mapping
CREATE TABLE feed_mapping (
	feed_id TEXT NOT NULL REFERENCES feeds(feed_id),
	category_id TEXT NOT NULL REFERENCES categories(category_id),
	PRIMARY KEY (feed_id, category_id)
);
```

With all pieces together, let's construct a query which extracts all rss feed URLs from our `blog-export` category.
```sql
SELECT feed_url 
FROM feeds 
INNER JOIN feed_mapping ON feeds.feed_id = feed_mapping.feed_id
INNER JOIN categories ON feed_mapping.category_id = categories.category_id
WHERE categories.label="blog-export";
```

Beautiful!

# Automation
I poured all this knowledge into a [python script](https://github.com/Milchdealer/teraku.de/tree/main/scripts/openring_from_news-flash.py) which basically runs this query and then starts the `openring` program, using the feeds as arguments.
I added it to my [deployment script](https://github.com/Milchdealer/teraku.de/tree/main/scripts/deploy.sh), which I run to update my blog, and the result you can see below. 🤓
