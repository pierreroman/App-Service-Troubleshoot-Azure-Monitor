<?php
// Only accept POST requests
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    exit('Method Not Allowed');
}

// Double Submit Cookie CSRF: compare cookie value with POST value
$cookieToken = $_COOKIE['csrf_token'] ?? '';
$postToken   = $_POST['csrf_token'] ?? '';
if ($cookieToken === '' || !hash_equals($cookieToken, $postToken)) {
    http_response_code(403);
    exit('Invalid CSRF token');
}

// Validate image count
$maxImages = filter_input(INPUT_POST, 'images', FILTER_VALIDATE_INT);
if ($maxImages === false || $maxImages < 1 || $maxImages > 100) {
    http_response_code(400);
    exit('Invalid image count');
}

// Intentional 403 for the troubleshooting tutorial:
// Selecting more than 3 images triggers an error for Azure Monitor diagnostics.
if ($maxImages > 3) {
    http_response_code(403);
    exit('Too many images selected — limit is 3 per batch.');
}

// Parse and whitelist image names (must match imgNN.jpg pattern)
$imgNamesRaw = $_POST['imgNames'] ?? '';
$imgNames = array_filter(explode(',', $imgNamesRaw));
$allowed = '/^img\d{1,3}\.(jpg|jpeg)$/i';

foreach ($imgNames as $name) {
    if (!preg_match($allowed, $name)) {
        http_response_code(400);
        exit('Invalid image name');
    }
}

// Convert each image one at a time (memory-efficient)
foreach ($imgNames as $name) {
    $source = __DIR__ . '/images/' . $name;
    if (!is_file($source)) {
        continue;
    }

    $outName = 'converted_' . pathinfo($name, PATHINFO_FILENAME) . '.png';
    $dest = __DIR__ . '/images/' . $outName;

    $img = imagecreatefromjpeg($source);
    if ($img) {
        imagepng($img, $dest);
        imagedestroy($img);
    }
}
