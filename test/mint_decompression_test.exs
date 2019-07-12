defmodule MintDecompressionTest do
  use ExUnit.Case
  @gzip_url "https://www.mozilla.org/en-US/"
  @br_url "https://www.google.com/"

  test "decompresses gzip response" do
    {:ok, conn} = MintDecompression.get(@gzip_url, [{"Accept-Encoding", "gzip"}])
    body = find_dragon(conn.data)
    assert body =~ ~S"""
                 _.-~-.
               7''  Q..\
            _7         (_
          _7  _/    _q.  /
        _7 . ___  /VVvv-'_                                            .
       7/ / /~- \_\\      '-._     .-'                      /       //
      ./ ( /-~-/||'=.__  '::. '-~'' {             ___   /  //     ./{
     V   V-~-~| ||   __''_   ':::.   ''~-~.___.-'' _/  // / {_   /  {  /
      VV/-~-~-|/ \ .'__'. '.    '::                     _ _ _        ''.
      / /~~~~||VVV/ /  \ )  \        _ __ ___   ___ ___(_) | | __ _   .::'
     / (~-~-~\\.-' /    \'   \::::. | '_ ` _ \ / _ \_  / | | |/ _` | :::'
    /..\    /..\__/      '     '::: | | | | | | (_) / /| | | | (_| | ::'
    vVVv    vVVv                 ': |_| |_| |_|\___/___|_|_|_|\__,_| ''
    """
  end

  test "does not decompress identity response" do
    {:ok, conn} = MintDecompression.get(@gzip_url, [])
    body = find_dragon(conn.data)
    assert body =~ ~S"""
                 _.-~-.
               7''  Q..\
            _7         (_
          _7  _/    _q.  /
        _7 . ___  /VVvv-'_                                            .
       7/ / /~- \_\\      '-._     .-'                      /       //
      ./ ( /-~-/||'=.__  '::. '-~'' {             ___   /  //     ./{
     V   V-~-~| ||   __''_   ':::.   ''~-~.___.-'' _/  // / {_   /  {  /
      VV/-~-~-|/ \ .'__'. '.    '::                     _ _ _        ''.
      / /~~~~||VVV/ /  \ )  \        _ __ ___   ___ ___(_) | | __ _   .::'
     / (~-~-~\\.-' /    \'   \::::. | '_ ` _ \ / _ \_  / | | |/ _` | :::'
    /..\    /..\__/      '     '::: | | | | | | (_) / /| | | | (_| | ::'
    vVVv    vVVv                 ': |_| |_| |_|\___/___|_|_|_|\__,_| ''
    """
  end

  test "does nothing for unsupported decompression" do
    assert {:ok, _conn} = MintDecompression.get(@br_url, [
      {"accept-encoding", "br"},
      {"user-agent", "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/75.0.3770.100 Safari/537.36"}
    ])
  end

  defp find_dragon(data) do
    lines = String.split(data, "\n")
    start_i = Enum.find_index(lines, fn line -> line =~ "_.-~-." end)
    end_i = Enum.find_index(lines, fn line -> line =~ "vVVv" end) + 1

    lines
    |> Enum.slice(start_i..end_i)
    |> Enum.join("\n")
  end
end
