var UzblHints = (function() {
	var autoFollow = 1;

	var uzbldivid = "uzbl_link_hint_div_container";

	var clear_hints = function() {
		var elements = document.getElementById(uzbldivid);
		if (elements) {
			elements.parentNode.removeChild(elements);
			return true;
		}
		return;
	};

	var elementPosition = function(el) {
		var up = el.offsetTop;
		var left = el.offsetLeft;
		var width = el.offsetWidth;
		var height = el.offsetHeight;
		while (el.offsetParent) {
			el = el.offsetParent;
			up += el.offsetTop;
			left += el.offsetLeft;
		}
		return [up, left, width, height];
	}

	/* TODO: also make hints change name to getHints? */
	var getElements = function(s, q) {
		clear_hints();
		var elements = document.querySelectorAll(q);
		var res = [];
		for (var l = 0; l < elements.length; l++) {
			var li = elements[l];
			/* check if element is in the viewport */
			var style = getComputedStyle(li, null);
			if (style.display !== "none" || style.visibility === "visible") {
				var offset = elementPosition(li);
				var up = offset[0];
				var left = offset[1];
				var width = offset[2];
				var height = offset[3];
				if (up < window.pageYOffset + window.innerHeight &&
					left < window.pageXOffset + window.innerWidth &&
					(up + height) > window.pageYOffset &&
					(left + width) > window.pageXOffset) {
					res.push(li);
				}
			}
		}
		return filter(s.match(/(\d+|[^\d\t;]+)/g), res);
	}

	var filter = function(needles, haystack) {
		if (!needles) {
			return haystack;
		}
		var i = -1;
		var needle;
		while ((needle = Number(needles[++i]) || needles[i])) {
			var bale = [];
			var j = -1;
			var strand;
			if (typeof needle === "string") {
				while ((strand = haystack[++j])) {
					var content = strand.text || strand.value;
					if (content && content.toLowerCase().indexOf(needle.toLowerCase()) > -1) {
						bale.push(strand);
					}
				}
			}
			else {
				var offset = (haystack.length < 10) ? 1 : (haystack.length < 100) ? 10 : 100;
				while ((strand = haystack[++j])) {
					if (String(j + offset).indexOf(needle) == 0) {
						bale.push(strand);
					}
				}
			}
			haystack = bale;
		}
		tmp["offset"] = offset;
		return haystack;
	};

	var generateHint = function (el, label, focused) {
		var pos = elementPosition(el);
		var hint = document.createElement('div');
		if (focused) {
			/* TODO: remove this */
			hint.setAttribute("class", "hint focused");
		}
		else {
			hint.setAttribute("class", "hint");
		}
		hint.setAttribute("style", [
			"position: absolute",
			"z-index: 999",
			focused ? "border: 2px solid #000" : "border: none",
			"margin: 0; padding:1px",
			"color: #FFF",
			"background-color: #777",
			"font: 9px/1 bold monospace",
			"text-decoration: none",
			"display: inline",
			"width: auto",
			"left:" + pos[1] + "px",
			"top:" +  pos[0] + "px",
			"opacity: 0.8",
			"-khtml-border-radius: 4px",
			"-khtml-transform: scale(1) rotate(0deg) translate(" + (focused ? "-8px,-7px" : "-6px,-5px") + ")"
		].join("; "));
		hint.appendChild(document.createTextNode(label));
		/* the image could be place else where and have nothing to do with this */
		// var img = el.getElementsByTagName('img');
		// if (img.length > 0) {
			// hint.style.left = pos[1] + img[0].width / 2 + 'px';
		// }
		return hint;
	};

	var exitInput = function(s) {
		var chars = s.length;
		while (chars) {
			Uzbl.run("keycmd_bs");
			chars--;
		}
	};

	var followHint = function(item) {
		if (item) {
			item.focus();
			switch (item.tagName) {
				case "TEXTAREA":
					/*jsl:fallthru*/
				case "SELECT":
					item.select();
					Uzbl.run("toggle_insert_mode 1");
					break;
				case 'INPUT':
					var type = item.type;
					if (type === "text" || type === "password" /* || type === "file" */) {
						Uzbl.run("toggle_insert_mode 1");
						// item.select();
						break;
					}
					/*jsl:fallthru*/
				default:
					var evt = document.createEvent("MouseEvents")
					evt.initMouseEvent("click", true, true, window, 1, 0, 0, 0, 0, false, false, false, false, 0, null);
					item.dispatchEvent(evt);
			}
		}
	}

	if (! Uzbl.run("print @loaded_hints")) {
		// Uzbl.run("bind :follow = keycmd :follow ");
		// Uzbl.run("bind :follow * = js UzblHints.follow(\"%s\")");
		// Uzbl.run("bind :follow = keycmd :Follow hint ")
		// Uzbl.run("bind :Follow hint * = js UzblHints.follow(\"%s\")");
		// Uzbl.run("bind :followWin * = js UzblHints.followWin(\"%s\")");
		// Uzbl.run("bind :followMulti * = js UzblHints.followMulti(\"%s\")");
		// Uzbl.run("bind :openGen * = js UzblHints.open(\"%s\")");
		// Uzbl.run("bind :winOpenGen * = js UzblHints.winOpenGen(\"%s\")");
		// Uzbl.run("bind :focus * = js UzblHints.focus(\"%s\")");
		// Uzbl.run("bind :focusFrame * = js UzblHints.focusFrame(\"%s\")");
		// Uzbl.run("bind :info * = js UzblHints.info(\"%s\")");
		// Uzbl.run("bind :save * = js UzblHints.save(\"%s\")");
		// Uzbl.run("bind :savePrompt * = js UzblHints.savePrompt(\"%s\")");
		// Uzbl.run("bind :source * = js UzblHints.source(\"%s\")");
		// Uzbl.run("bind :sourceExt * = js UzblHints.sourceExt(\"%s\")");
		// Uzbl.run("bind :yankLoc * = js UzblHints.yankLoc(\"%s\")");
		// Uzbl.run("bind :yankDesc * = js UzblHints.yankDesc(\"%s\")");
		Uzbl.run("set loaded_hints = 1"); /* custom variables are not supported yet :( */
	}

	var tmp = {target: null, offset: 0};

	return {
		"follow": function (s) { // # bind f and ;o # Follow hint
			var elements = getElements(s, "a, button, input:not([type='hidden']), select, textarea, [onclick]");

			if (autoFollow && elements.length === 1) {
				exitInput(":follow " + s);
				followHint(elements[0]);
				return;
			}

			var foo = s.match(/(\d*)([\t;]*)$/);
			var focusOffset = foo[2].length;
			var digitLen = foo[1].length;
			if (digitLen) {
				var labelOffset = tmp["offset"];
			}
			else {
				labelOffset = (elements.length < 10) ? 1 : (elements.length < 100) ? 10 : 100;
			}

			// var hints = document.createDocumentFragment();
			var hintdiv = document.createElement("div");
			hintdiv.setAttribute("id", uzbldivid);
			var i = -1;
			var element;
			while ((element = elements[++i])) {
				var label = String(i + labelOffset).slice(digitLen) || "&#10140;";
				var focused = (i === focusOffset);
				hintdiv.appendChild(generateHint(element, label, focused));
				if (focused) {
					tmp["target"] = element;
				}
			}
			document.getElementsByTagName("body")[0].appendChild(hintdiv);

			window.addEventListener("keyup", function(e) {
					/* TODO: stop this being run multiple times! */
					switch(e.keyCode) {
						case (e.DOM_VK_ENTER || 13):
							if (clear_hints() && tmp["target"]) {
								followHint(tmp["target"]);
							}
							/*jsl:fallthru*/
						case (e.DOM_VK_ESCAPE || 27):
							clear_hints();
							window.removeEventListener("keyup", arguments.callee, false);
							/*jsl:fallthru*/
					}
				}, false);
		},
		"followWin": function (s) { // # bind ;w # Follow hint in a new window
			var elements = getElements("a[href]");
		},
		"followMulti": function (s) { // # bind ;F # Open multiple hints in tabs
			var elements = getElements("a[href]");
		},
		"focus": function (s) { // bind ;; # Focus hint
			var elements = getElements("a, button, input:not([type='hidden']), textarea, select, object");
		},
		"focusFrame": function (s) { // # bind ;f # Focus frame
			var elements = getElements("iframe, object[type='text/html'], object[type='application/xhtml+xml']", "frame");
		},
		"info": function (s) { // # bind ;? # Show information for hint
			/* be nice to use the inspector... */
		},
		"save": function (s) { // # bind ;s # Save hint
			/* currently not possible? */
			var elements = getElements("a[href]");
		},
		"savePrompt": function (s) { // # bind ;a # Save hint with prompt
			/* ... */
			var elements = getElements("a[href]");
			/* replace ~ with $HOME */
		},
		"source": function (s) { // # bind ;v # View hint source
			/* hmmmm? */
		},
		"sourceExt": function (s) { // # bind ;V # View hint source in external editor
			/* easy */
		},
		"yankLoc": function (s) { // # bind ;y # Yank hint location
			/* xclip */
			var elements = getElements("a[href]");
		},
		"yankDesc": function (s) { // # bind ;Y # Yank hint description
			/* ... */
			var elements = getElements("a[href]");
		}
	};
})();