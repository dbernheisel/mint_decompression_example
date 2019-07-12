defmodule MintDecompressionTest do
  use ExUnit.Case
  @gzip_url "http://httpbin.org/gzip"
  @br_url "http://httpbin.org/brotli"
  @deflate_url "http://httpbin.org/deflate"
  @nocompress_url "http://httpbin.org/encoding/utf8"

  test "decompresses gzip response" do
    {:ok, conn} = MintDecompression.get(@gzip_url, [{"Accept-Encoding", "gzip"}])
    assert conn.data =~ "gzipped"
  end

  test "decompresses deflated response" do
    {:ok, conn} = MintDecompression.get(@deflate_url, [])
    assert conn.data =~ "deflated"
  end

  test "does not change identity response" do
    {:ok, conn} = MintDecompression.get(@nocompress_url, [])
    assert conn.data =~ "Unicode Demo"
  end

  test "does nothing for unsupported decompression" do
    assert {:ok, _conn} = MintDecompression.get(@br_url, [
      {"accept-encoding", "br"},
      {"user-agent", "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/75.0.3770.100 Safari/537.36"}
    ])
  end
end
