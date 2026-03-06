<?php
header('Content-Type: application/json');

$thumbs = [];
$dir = __DIR__ . '/thumbs';

if (is_dir($dir) && $handle = opendir($dir)) {
    while (false !== ($entry = readdir($handle))) {
        if ($entry === '.' || $entry === '..') {
            continue;
        }
        $ext = strtolower(pathinfo($entry, PATHINFO_EXTENSION));
        if (in_array($ext, ['jpg', 'jpeg', 'png', 'gif', 'webp'], true)) {
            $thumbs[] = $entry;
        }
    }
    closedir($handle);
}

sort($thumbs);
echo json_encode($thumbs);
