# avtr.dev

A service to retrieve avatars given a URL.

## Usage

To retrieve an image for a given URL, send a `GET` request to the root of the service with the `url` query parameter set to the URL you want to retrieve an avatar for.

```bash
GET /?url=https://jamesg.blog

# Response
{
"avatar": "https://jamesg.blog/assets/coffeeshop.jpeg"
}
```

## Logic

avtr.dev uses the following logic to determine the avatar for a given URL:

1. Checks for a h-card on the provided URL. If one is available, the avatar is set to the `photo` property of the h-card.
2. Checks for a `link` tag with a `rel` attribute of, in order: `icon`, `shortcut icon`, `apple-touch-icon`, `apple-touch-icon-precomposed`. If one is available, the avatar is set to the `href` attribute of the `link` tag.
3. Checks for a Gravatar associated with the provided URL. If one is available, the avatar is set to the Gravatar URL.
4. Checks for a GitHub account associated with the provided URL. If one is available, the avatar is set to the GitHub avatar URL.
5. Returns `null`.

## License

This project is licensed under an MIT No Attribution license. See the [LICENSE](LICENSE) file for details.

## Contributors

- capjamesg
