<?php

$requestUri = urldecode(parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH) ?: '/');
$publicPath = __DIR__.'/public';
$requestedPath = realpath($publicPath.$requestUri);

if (
    $requestedPath !== false &&
    str_starts_with($requestedPath, realpath($publicPath) ?: $publicPath) &&
    is_file($requestedPath)
) {
    return false;
}

require $publicPath.'/index.php';
