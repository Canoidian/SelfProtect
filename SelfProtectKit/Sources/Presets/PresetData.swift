import Foundation

public struct PresetData: Sendable {
    public static let allPresets: [BlockPreset] = [
        BlockPreset(
            name: "Social Media",
            symbolName: "bubble.left.and.bubble.right",
            websites: [
                "facebook.com", "instagram.com", "x.com", "twitter.com",
                "linkedin.com", "tiktok.com", "snapchat.com", "reddit.com",
                "pinterest.com", "threads.net", "bsky.app", "whatsapp.net"
            ],
            apps: [
                "com.facebook.Mac": "Facebook",
                "com.instagram.Instagram": "Instagram",
                "com.linkedin.LinkedIn": "LinkedIn",
                "com.reddit.Reddit": "Reddit",
                "com.tiktok.Short": "TikTok",
                "com.twitter.x": "X (Twitter)",
                "com.snap.Snapchat": "Snapchat",
                "com.pinterest.Pinterest": "Pinterest",
                "com.atebits.Tweetie2": "Tweetbot",
                "com.tapbots.Tweetbot": "Tweetbot"
            ]
        ),
        BlockPreset(
            name: "Entertainment",
            symbolName: "play.rectangle",
            websites: [
                "youtube.com", "netflix.com", "hulu.com", "disneyplus.com",
                "spotify.com", "twitch.tv", "vimeo.com", "primevideo.com",
                "hbomax.com", "max.com", "peacocktv.com", "paramountplus.com",
                "appletv.apple.com", "music.apple.com"
            ],
            apps: [
                "com.google.YouTube": "YouTube",
                "com.netflix.Netflix": "Netflix",
                "com.hulu.Hulu": "Hulu",
                "com.disney.DisneyPlus": "Disney+",
                "com.spotify.client": "Spotify",
                "com.twitch.Twitch": "Twitch",
                "com.primevideo.PrimeVideo": "Prime Video",
                "com.apple.TV": "Apple TV",
                "com.apple.Music": "Apple Music",
                "com.plex.Plex": "Plex",
                "com.vimeo.Vimeo": "Vimeo"
            ]
        ),
        BlockPreset(
            name: "Gaming",
            symbolName: "gamecontroller",
            websites: [
                "steamcommunity.com", "steampowered.com", "discord.com",
                "epicgames.com", "roblox.com", "battle.net", "xbox.com",
                "playstation.com", "nintendo.com", "origin.com", "ea.com",
                "ubisoft.com", "rockstargames.com"
            ],
            apps: [
                "com.valve.steam": "Steam",
                "com.discord.Discord": "Discord",
                "com.epicgames.EpicGamesLauncher": "Epic Games",
                "com.blizzard.BNLaunch": "Battle.net",
                "com.roblox.Roblox": "Roblox",
                "com.spotify.client": "Spotify",
                "net.java.openjdk.cmd": "Minecraft",
                "com.mojang.mojang": "Minecraft",
                "com.heroes.arena": "Heroes Arena"
            ]
        ),
        BlockPreset(
            name: "News",
            symbolName: "newspaper",
            websites: [
                "cnn.com", "nytimes.com", "wsj.com", "washingtonpost.com",
                "bbc.com", "bbc.co.uk", "reuters.com", "theguardian.com",
                "bloomberg.com", "npr.org", "foxnews.com", "msnbc.com",
                "abcnews.go.com", "nbcnews.com", "cbsnews.com", "usatoday.com",
                "theverge.com", "arstechnica.com", "techcrunch.com",
                "wired.com", "medium.com", "news.ycombinator.com"
            ],
            apps: [:]
        ),
        BlockPreset(
            name: "Shopping",
            symbolName: "cart",
            websites: [
                "amazon.com", "ebay.com", "etsy.com", "walmart.com",
                "target.com", "bestbuy.com", "homedepot.com", "costco.com",
                "newegg.com", "kohls.com", "nordstrom.com", "macys.com",
                "shein.com", "temu.com", "aliexpress.com", "shop.app",
                "zillow.com", "realtor.com"
            ],
            apps: [
                "com.amazon.Amazon": "Amazon",
                "com.ebay.Ebay": "eBay",
                "com.etsy.Etsy": "Etsy",
                "com.walmart.Walmart": "Walmart",
                "com.target.Target": "Target",
                "com.bestbuy.bestbuy": "Best Buy",
                "com.shop.Shop": "Shop"
            ]
        ),
        BlockPreset(
            name: "Video Streaming",
            symbolName: "film",
            websites: [
                "youtube.com", "netflix.com", "hulu.com", "disneyplus.com",
                "twitch.tv", "vimeo.com", "primevideo.com", "hbomax.com",
                "max.com", "peacocktv.com", "paramountplus.com", "dailymotion.com",
                "crunchyroll.com", "funimation.com"
            ],
            apps: [
                "com.google.YouTube": "YouTube",
                "com.netflix.Netflix": "Netflix",
                "com.hulu.Hulu": "Hulu",
                "com.disney.DisneyPlus": "Disney+",
                "com.twitch.Twitch": "Twitch",
                "com.primevideo.PrimeVideo": "Prime Video",
                "com.apple.TV": "Apple TV",
                "com.crunchyroll.Crunchyroll": "Crunchyroll"
            ]
        ),
        BlockPreset(
            name: "Productivity Busters",
            symbolName: "timer",
            websites: [
                "reddit.com", "twitter.com", "x.com", "facebook.com",
                "instagram.com", "tiktok.com", "pinterest.com",
                "9gag.com", "imgur.com", "buzzfeed.com", "boredpanda.com",
                "theuselessweb.com", "reddit.com"
            ],
            apps: [
                "com.reddit.Reddit": "Reddit",
                "com.twitter.x": "X (Twitter)",
                "com.facebook.Mac": "Facebook",
                "com.instagram.Instagram": "Instagram",
                "com.pinterest.Pinterest": "Pinterest"
            ]
        )
    ]
}
