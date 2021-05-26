import Foundation

public struct WidgetFeaturedContent: Codable {

	// MARK: - Nested Types

	enum CodingKeys: String, CodingKey {
		case featuredArticle = "tfa"
	}

	public struct FeaturedArticleContent: Codable {

		// MARK: - Featured Article - Nested Types

		enum CodingKeys: String, CodingKey {
			case displayTitle = "displaytitle"
			case description
			case extract
			case languageDirection = "dir"
			case contentURL = "content_urls"
			case thumbnailSource = "thumbnail"
			case originalImageSource = "originalimage"
		}

		public struct ContentURL: Codable {
			public struct Desktop: Codable {
				public let page: String
			}

			public let desktop: Desktop
		}

		public struct ImageSource: Codable {
			let source: String
		}

		// MARK: - Featured Article - Properties

		public let displayTitle: String
		public let description: String?
		public let extract: String
		public let languageDirection: String
		public let contentURL: ContentURL
		public let thumbnailSource: ImageSource?
		public let originalImageSource: ImageSource?
	}

	// MARK: - Properties

	public let fetchDate = Date()
	public let featuredArticle: FeaturedArticleContent?

}
