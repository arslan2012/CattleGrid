fetch('./ExportOptions.plist')
  .then(function(response) {
    return response.text();
  })
  .then(function(text) {
    const doc = plist.parse(text);
    const {manifest} = doc;

    const downloadLink = document.getElementById('appURL');
    downloadLink.href = manifest.appURL;

    const displayImage = document.getElementById('displayImage');
    displayImage.src = manifest.fullSizeImageURL;
  });
