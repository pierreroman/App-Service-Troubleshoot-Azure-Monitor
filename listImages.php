<?php
// Whitelist allowed extensions
$allowedExts = ['jpg', 'jpeg', 'png'];
$extension = $_GET['ext'] ?? '';

if (!in_array(strtolower($extension), $allowedExts, true)) {
    http_response_code(400);
    exit('Invalid extension');
}

$noImages = true;
$dir = __DIR__ . '/images';

if (is_dir($dir) && $handle = opendir($dir)) {
    while (false !== ($entry = readdir($handle))) {
        if ($entry === '.' || $entry === '..') {
            continue;
        }

        $fileExt = strtolower(pathinfo($entry, PATHINFO_EXTENSION));
        if ($fileExt === strtolower($extension)) {
            echo htmlspecialchars($entry, ENT_QUOTES, 'UTF-8') . "\n<br/>";
            $noImages = false;
        }
    }
    closedir($handle);
}

if ($noImages) {
    echo 'No images found';
}
