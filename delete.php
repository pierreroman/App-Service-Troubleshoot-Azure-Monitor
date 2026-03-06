<?php
session_start();

// Only accept POST requests
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    exit('Method Not Allowed');
}

// Validate CSRF token
if (!hash_equals($_SESSION['csrf_token'] ?? '', $_POST['csrf_token'] ?? '')) {
    http_response_code(403);
    exit('Invalid CSRF token');
}

$noImages = true;
$dir = __DIR__ . '/images';

if (is_dir($dir) && $handle = opendir($dir)) {
    while (false !== ($entry = readdir($handle))) {
        if ($entry === '.' || $entry === '..') {
            continue;
        }

        // Only delete files matching the converted_*.png pattern
        if (preg_match('/^converted_.*\.png$/i', $entry)) {
            $filepath = $dir . '/' . $entry;
            if (is_file($filepath)) {
                if (!unlink($filepath)) {
                    echo 'Error deleting ' . htmlspecialchars($entry, ENT_QUOTES, 'UTF-8') . "<br/>\n";
                } else {
                    echo 'Deleted ' . htmlspecialchars($entry, ENT_QUOTES, 'UTF-8') . "<br/>\n";
                    $noImages = false;
                }
            }
        }
    }
    closedir($handle);
}

if ($noImages) {
    echo 'No images found';
}