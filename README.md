# MintDecompression

This serves as an example of how to decompress data using Elixir's
[Mint](https://github.com/ericmj/mint) library

It starts by using the architecture from Mint's guide:
https://github.com/ericmj/mint/blob/d782ed6aaa9d6150a2569d6c77a2c81e5d6b32ec/pages/Architecture.md

It's then modified:
1) when Mint is done with the request, look for a content-encoding header
2) with that header, try to decompress the body
3) return the decompressed body instead of the original binary body

This starts with `process_response({:done, request_ref}, state)` clause, and
then uses `decompress_data/2` and `find_content_encoding/1`
