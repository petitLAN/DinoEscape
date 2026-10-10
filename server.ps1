param([ValidateRange(1,65535)][int]$Port = 8000)

$ErrorActionPreference = 'Stop'
$root = [System.IO.Path]::GetFullPath($PSScriptRoot)
$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add("http://localhost:$Port/")
$mime = @{
  '.html'='text/html; charset=utf-8'; '.htm'='text/html; charset=utf-8';
  '.css'='text/css; charset=utf-8'; '.js'='text/javascript; charset=utf-8';
  '.mjs'='text/javascript; charset=utf-8'; '.json'='application/json; charset=utf-8';
  '.svg'='image/svg+xml'; '.png'='image/png'; '.jpg'='image/jpeg';
  '.jpeg'='image/jpeg'; '.gif'='image/gif'; '.webp'='image/webp';
  '.ico'='image/x-icon'; '.woff'='font/woff'; '.woff2'='font/woff2';
  '.ttf'='font/ttf'; '.otf'='font/otf'; '.wasm'='application/wasm';
  '.mp3'='audio/mpeg'; '.wav'='audio/wav'; '.ogg'='audio/ogg';
  '.mp4'='video/mp4'; '.webm'='video/webm'; '.pdf'='application/pdf';
  '.txt'='text/plain; charset=utf-8'; '.xml'='application/xml';
  '.webmanifest'='application/manifest+json'; '.map'='application/json'
}

try {
  $listener.Start()
  Write-Host "Website: http://localhost:$Port/" -ForegroundColor Green
  Write-Host "Map: $root"
  Write-Host 'Sluit dit venster of druk op Ctrl+C om te stoppen.'
  Start-Process "http://localhost:$Port/"
  while ($listener.IsListening) {
    $context = $listener.GetContext()
    $response = $context.Response
    try {
      $method = $context.Request.HttpMethod
      if ($method -ne 'GET' -and $method -ne 'HEAD') {
        $response.StatusCode = 405
        $response.Headers['Allow'] = 'GET, HEAD'
        continue
      }
      $path = [Uri]::UnescapeDataString($context.Request.Url.AbsolutePath).Replace('/', [IO.Path]::DirectorySeparatorChar)
      $relative = $path.TrimStart([IO.Path]::DirectorySeparatorChar)
      $file = [IO.Path]::GetFullPath([IO.Path]::Combine($root, $relative))
      if (-not $file.StartsWith($root.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -and $file -ne $root) {
        $response.StatusCode = 403
        continue
      }
      if (Test-Path -LiteralPath $file -PathType Container) {
        $file = Join-Path $file 'index.html'
      }
      if (-not (Test-Path -LiteralPath $file -PathType Leaf)) {
        $response.StatusCode = 404
        $bytes = [Text.Encoding]::UTF8.GetBytes('404 - Bestand niet gevonden')
        $response.ContentType = 'text/plain; charset=utf-8'
        $response.ContentLength64 = $bytes.Length
        if ($method -eq 'GET') { $response.OutputStream.Write($bytes, 0, $bytes.Length) }
        continue
      }
      $extension = [IO.Path]::GetExtension($file).ToLowerInvariant()
      if ($mime.ContainsKey($extension)) { $response.ContentType = $mime[$extension] }
      else { $response.ContentType = 'application/octet-stream' }
      $response.Headers['Cache-Control'] = 'no-cache'
      $stream = [IO.File]::Open($file, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
      try {
        $response.ContentLength64 = $stream.Length
        if ($method -eq 'GET') { $stream.CopyTo($response.OutputStream) }
      } finally { $stream.Dispose() }
      Write-Host "$method $($context.Request.Url.AbsolutePath) -> $($response.StatusCode)"
    } catch {
      Write-Warning $_.Exception.Message
      try { $response.StatusCode = 500 } catch {}
    } finally {
      try { $response.Close() } catch {}
    }
  }
} catch {
  Write-Host "Server kon niet starten: $($_.Exception.Message)" -ForegroundColor Red
  exit 1
} finally {
  if ($listener.IsListening) { $listener.Stop() }
  $listener.Close()
}
