<?php
session_start();
if (empty($_SESSION['csrf_token'])) {
    $_SESSION['csrf_token'] = bin2hex(random_bytes(32));
}
?>
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="description" content="Sample troubleshooting app to use with Azure App Service.">
    <meta name="author" content="Mangesh Sangapu">
    <meta name="csrf-token" content="<?= htmlspecialchars($_SESSION['csrf_token'], ENT_QUOTES, 'UTF-8') ?>">

    <title>Image Converter</title>

    <!-- Bootstrap 5.3 -->
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet" crossorigin="anonymous">
    <link href="starter-template.css" rel="stylesheet">
  </head>

  <body>

    <nav class="navbar navbar-expand-md navbar-dark bg-dark fixed-top">
      <div class="container-fluid">
        <a class="navbar-brand" href="#">Image Converter</a>
        <button class="navbar-toggler" type="button" data-bs-toggle="collapse" data-bs-target="#navbarMain" aria-controls="navbarMain" aria-expanded="false" aria-label="Toggle navigation">
          <span class="navbar-toggler-icon"></span>
        </button>

        <div class="collapse navbar-collapse" id="navbarMain">
          <ul class="navbar-nav me-auto">
            <li class="nav-item">
              <a class="nav-link active" aria-current="page" href="#">Home</a>
            </li>
            <li class="nav-item dropdown">
              <a class="nav-link dropdown-toggle" href="#" role="button" data-bs-toggle="dropdown" aria-expanded="false">Tools</a>
              <ul class="dropdown-menu">
                <li><a class="dropdown-item" data-bs-toggle="modal" data-bs-target="#viewModal" href="#">View Images</a></li>
                <li><a class="dropdown-item" data-bs-toggle="modal" data-bs-target="#convertModal" href="#">Convert to PNG</a></li>
              </ul>
            </li>
            <li class="nav-item">
              <a class="nav-link" href="#" data-bs-toggle="modal" data-bs-target="#aboutModal">About</a>
            </li>
          </ul>
        </div>
      </div>
    </nav>

    <main class="container">
      <div class="starter-template">
        <p class="lead">ImageConverter is a sample app for Azure App Service.<br/>
        This app should be used along with this <a href="https://docs.microsoft.com/azure/app-service/containers/tutorial-troubleshoot-monitor">tutorial</a>.</p>
      </div>
    </main>

    <!-- Convert Modal -->
    <div class="modal fade" id="convertModal" tabindex="-1" aria-labelledby="convertModalLabel" aria-hidden="true">
      <div class="modal-dialog modal-dialog-centered modal-lg">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title" id="convertModalLabel">Select JPGs to convert to PNG</h5>
            <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
          </div>
          <div class="modal-body">
            <div id="thumbGallery" class="row g-3">
              <!-- Thumbnails loaded dynamically from getThumbs.php -->
            </div>
          </div>
          <div class="modal-footer">
            <span id="message"></span>
            <button id="process" type="button" class="btn btn-primary">Convert</button>
            <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Close</button>
          </div>
        </div>
      </div>
    </div>

    <!-- View Modal -->
    <div class="modal fade" id="viewModal" tabindex="-1" aria-labelledby="viewModalLabel" aria-hidden="true">
      <div class="modal-dialog modal-dialog-centered modal-lg">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title" id="viewModalLabel">Image Listing</h5>
            <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
          </div>
          <div class="modal-body">
            <table class="table">
              <tr>
                <td><strong>JPG Images</strong><br/><span id="jpg"></span></td>
                <td><strong>Converted PNG Images</strong><br/><span id="png"></span></td>
              </tr>
            </table>
          </div>
          <div class="modal-footer">
            <button id="delete" type="button" class="btn btn-danger">Delete Converted Images</button>
            <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Close</button>
          </div>
        </div>
      </div>
    </div>

    <!-- About Modal -->
    <div class="modal fade" id="aboutModal" tabindex="-1" aria-labelledby="aboutModalLabel" aria-hidden="true">
      <div class="modal-dialog modal-dialog-centered">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title" id="aboutModalLabel">About</h5>
            <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
          </div>
          <div class="modal-body">
            Sample App Created by <a href="mailto:msangapu@outlook.com">Mangesh Sangapu</a> for use with
            <a href="https://docs.microsoft.com/azure/app-service/">Azure App Service.</a><br/>
            This app should be used along with this
            <a href="https://docs.microsoft.com/azure/app-service/containers/tutorial-troubleshoot-monitor">Troubleshooting Tutorial</a>.
          </div>
          <div class="modal-footer">
            <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Close</button>
          </div>
        </div>
      </div>
    </div>

    <!-- Bootstrap 5.3 Bundle (includes Popper) -->
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js" crossorigin="anonymous"></script>
    <script src="app.js"></script>
  </body>
</html>
