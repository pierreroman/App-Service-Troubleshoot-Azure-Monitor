document.addEventListener('DOMContentLoaded', function () {
    'use strict';

    var csrfToken = document.querySelector('meta[name="csrf-token"]').getAttribute('content');

    // --- Convert Modal ---
    var convertModalEl = document.getElementById('convertModal');
    var convertModal = bootstrap.Modal.getOrCreateInstance(convertModalEl);

    convertModalEl.addEventListener('shown.bs.modal', loadThumbnails);

    convertModalEl.addEventListener('hidden.bs.modal', function () {
        document.getElementById('thumbGallery').innerHTML = '';
        document.getElementById('message').textContent = '';
    });

    // --- View Modal ---
    var viewModalEl = document.getElementById('viewModal');
    var viewModal = bootstrap.Modal.getOrCreateInstance(viewModalEl);

    viewModalEl.addEventListener('shown.bs.modal', function () {
        loadImageList('jpg', 'jpg');
        loadImageList('png', 'png');
    });

    viewModalEl.addEventListener('hidden.bs.modal', function () {
        document.getElementById('jpg').innerHTML = '';
        document.getElementById('png').innerHTML = '';
    });

    // --- Convert Button ---
    document.getElementById('process').addEventListener('click', function () {
        var selected = document.querySelectorAll('#thumbGallery img.selected');

        if (selected.length === 0) {
            alert('Please select at least one image.');
            return;
        }

        var imgNames = Array.from(selected).map(function (img) {
            return img.getAttribute('src').split('/').pop();
        });

        document.getElementById('message').innerHTML =
            '<div class="spinner-border spinner-border-sm" role="status">' +
            '<span class="visually-hidden">Converting…</span></div>';

        var body = new URLSearchParams();
        body.append('csrf_token', csrfToken);
        body.append('images', imgNames.length);
        body.append('imgNames', imgNames.join(','));

        fetch('process.php', { method: 'POST', body: body })
            .then(function (response) {
                if (!response.ok) throw new Error('HTTP ' + response.status);
                return response.text();
            })
            .then(function () {
                alert(imgNames.length + ' image(s) converted.\nClick Tools \u2192 View Images to confirm.');
                convertModal.hide();
            })
            .catch(function (err) {
                alert('Error: ' + err.message);
                document.getElementById('message').textContent = '';
            });
    });

    // --- Delete Button ---
    document.getElementById('delete').addEventListener('click', function () {
        var body = new URLSearchParams();
        body.append('csrf_token', csrfToken);

        fetch('delete.php', { method: 'POST', body: body })
            .then(function (response) {
                if (!response.ok) throw new Error('HTTP ' + response.status);
                return response.text();
            })
            .then(function () {
                alert('Deleted converted images.');
                viewModal.hide();
            })
            .catch(function (err) {
                alert('Error: ' + err.message);
            });
    });

    // --- Helpers ---

    function loadThumbnails() {
        fetch('getThumbs.php')
            .then(function (r) { return r.json(); })
            .then(function (thumbs) {
                var gallery = document.getElementById('thumbGallery');
                gallery.innerHTML = '';

                thumbs.forEach(function (name) {
                    var col = document.createElement('div');
                    col.className = 'col-6 col-sm-3 col-md-2';

                    var img = document.createElement('img');
                    img.src = './thumbs/' + encodeURIComponent(name);
                    img.alt = name;
                    img.width = 100;
                    img.height = 100;
                    img.className = 'img-thumbnail';
                    img.style.cursor = 'pointer';
                    img.addEventListener('click', toggleSelection);

                    col.appendChild(img);
                    gallery.appendChild(col);
                });
            })
            .catch(function () {
                document.getElementById('thumbGallery').textContent = 'Failed to load thumbnails.';
            });
    }

    function toggleSelection() {
        this.classList.toggle('selected');
        var count = document.querySelectorAll('#thumbGallery img.selected').length;
        document.getElementById('message').textContent = count > 0 ? count + ' image(s) selected' : '';
    }

    function loadImageList(ext, targetId) {
        fetch('listImages.php?ext=' + encodeURIComponent(ext))
            .then(function (r) { return r.text(); })
            .then(function (data) {
                document.getElementById(targetId).innerHTML = data;
            });
    }
});
