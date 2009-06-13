/* This script follows the first "next" link it finds on the page. */

var links = document.links;

var next_text = /next/i;

for(var i = 0; i < links.length; ++i) {
  if (next_text.test(links[i].text)) {
    window.location = links[i].href;
    break;
  }
}
