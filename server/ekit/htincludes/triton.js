// $Id: triton.js,v 1.8 2013-11-26 23:03:45 triton Exp $
// This is the basic handler which uses the "dirty" variable to decide
// whether to stop the user from leaving the page.

var dirty;
var saveevery = 15;		// Autosaves every n seconds if dirty
var n;
var t;
var handles = new Array();
//var useDojo = true;		// Superceded by extras.dojo.enabled

//  //  //  //  S u b r o u t i n e s   f o l l o w . . . //  //  //  // //  // //
// The first group of functions are dojo-free, and can run regardless, so they 
// don't need to check the extras.dojo.enabled flag at all
//
// Clear the output frame
//
function resetme() {
	return;
}

function clearoutput(){
	o = document.getElementById("output");
	if (o){
		var doc = o.contentDocument;
		if (doc === undefined || doc === null)
		    doc = o.contentWindow.document;
		doc.open();
		doc.write('Next time your form is saved, this frame will be updated');
		doc.close();
	}
}
//
// Can we let them go?
//
function dontleaveme(e) {
	var mesg = "";
	if (dirty) {
		if (document.getElementById("response"))
			document.getElementById("response").innerHTML = "Your data needs to be saved";
		mesg = "If you leave this page now, you will lose any data you have entered in the last "+saveevery+" seconds. ";	
//		console.info("Please don't go, we have unfinished business");
		}
// For Firefox and others...
	if (navigator.appName != 'Microsoft Internet Explorer') 
		e.returnValue = mesg;
// For all others

//    if (mesg != "")
	if ((navigator.appName === 'Microsoft Internet Explorer') && (mesg === ""))
		{ //Don't return anything for ie and not dirty
//		console.info("IE browser, not dirty");
		}
	else
		return mesg;
}

// 
// Called to clear the dirty flag
//
function clr(){
	dirty = false;
//	console.info("Cleared dirty flag");
}
//
// Called to set the dirty flag
//
function yuk() {
	if (!dirty){
		dirty = true;
//		console.info("Dirty");
		if (extras.dojo.enabled && document.getElementById("response"))
			document.getElementById("response").innerHTML = '<img src="/pix/203.script2.gif" align="top"> Modified';
	}
	n = saveevery;
}
//
//	This handles the normal submit, by removing the dojo handler, 
//  calling QValid() and then doing a submit.
//
function mysubmit() {
	if (document.q.jump_to)
		document.q.jump_to.value="";
	if (document.q.BACK2)
		document.q.BACK2.value="";
	if (QValid()){							// If it validates, submit it
		rmsubmithandler();
		document.q.submit();
		}
	return false;							// Prevents a possible double submit
}
//
//	This is similar to the above, but asks to go BACK (using Back2)
//
function mysubmitback() {
	if (document.q.jump_to)
		document.q.jump_to.value="";
	if (document.q.BACK2)
		document.q.BACK2.value="1";
	if (QValid()){							// If it validates, submit it
		rmsubmithandler();
		document.q.submit();
		}
	return false;							// Prevents a possible double submit
}
// - - - - - - - - - - - - - - - - - - - - 
// DOJO USED FROM HERE ON...
//

//
// This is invoked every 5 seconds...
// ONLY CALLED IF DOJO ENABLED
function ticker(){
	n -= 5;
	if (dirty) {
//		console.info("Autosaving in "+n+" secs");
		if (document.getElementById("response"))
			document.getElementById("response").innerHTML = document.getElementById("response").innerHTML + "..";
	} else {
//		console.info("Tick..."+n);
	}
	if (n <= 0){
//		console.info('Checking...');
		if (dirty) {
			sendNow();
		}
		n = saveevery;
	} 
}

//
// Removes submit handler, ready for a submit 
// 
function rmsubmithandler() {
	if (typeof extras != 'undefined') {
		if (extras.dojo.enabled) {
			if (handles["submit"]){					// Remove old Dojo submit handler
				dojo.disconnect(handles["submit"]);
//				console.info("Removed submit handler");
				dirty = false;
			}
		}
	}
}

//
// Does the Ajax send of the form for auto-save
//
// ONLY CALLED IF DOJO ENABLED
function sendNow(event){
    // Stop the submit event since we want to control form submission.
    if (event)
    	dojo.stopEvent(event);
	dirty = false;
	n = saveevery;		// Reset the timer now
//	console.info("Sending data ");
	showoutput("Waiting for response from server...");

    // The parameters to pass to xhrPost, the form, how to handle it, and the callbacks.
    // Note that there isn't a url passed.  xhrPost will extract the url to call from the form's
    //'action' attribute.  You could also leave off the action attribute and set the url of the xhrPost object
    // either should work.
    var xhrArgs = {
      form: document.getElementById("q"),
      handleAs: "text",
      load: function(data){
		if (document.getElementById("response"))
	        document.getElementById("response").innerHTML = '<img src="/pix/206.greencheck.gif" align="top"> Saved.';
// Putting the returned data straight into a HTML container does show it, 
// but it also throws an exception, which is not desirable.
//        document.getElementById("returned").innerHTML = data;
		showoutput(data);
		if (document.getElementById("BACK2"))
			document.getElementById("BACK2").value = '';
		n = saveevery;		// Reset the timer now
      },
      error: function(error){
		if (document.getElementById("response"))
	        document.getElementById("response").innerHTML = "That ended badly: "+error;
      }
    }
    // Call the asynchronous xhrPost
	if (document.getElementById("response"))
	    document.getElementById("response").innerHTML = '<img src="/pix/ajax-loader.gif" align="top"> Saving...';
    var deferred = dojo.xhrPost(xhrArgs);
  }

function setupSendForm(){
	if (document.getElementById("response"))
	    document.getElementById("response").innerHTML = "Ready";
	dirty = false;
	n = saveevery;		// Set initial wait
	if (extras.dojo.enabled) {
		form = document.getElementById("q");
		if (!form)
			alert("Couldn't find a form 'q' on the page");
		else {
			handles["submit"] = dojo.connect(form, "onsubmit", sendNow);
			t = new dojox.timing.Timer(5000);
			t.onTick = ticker;
			t.start();
			//	Form dirty handler:
			handles["unload"] = dojo.connect(window, "onbeforeunload", this, "dontleaveme");
		}
	}
	clearoutput();
}
//
// Show data returned from Ajax call if output frame is visible
//
function showoutput(responsedata){
	o = document.getElementById("output");
	if (o){
		if (o.style.visibility === 'visible') {
			var doc = o.contentDocument;
			if (doc === undefined || doc === null)
			    doc = o.contentWindow.document;
			doc.open();
			doc.write(responsedata);
			doc.close();
			if (document.getElementById("response"))
				document.getElementById("response").innerHTML = document.getElementById("response").innerHTML + ", debug frame updated."; 
	//	    alert("Updated output frame contents");  
		}
	}
}
//
// Toggle the visibility of the output frame
//
function toggleoutput(){
	o = document.getElementById('output');
	if (o){
		if (o.style.visibility === 'visible'){
			o.style.visibility = 'hidden';
			clearoutput();
		}else{
			o.style.visibility = 'visible';
		}
	}
}
//
// This one does an Ajax save, and then uses the browser history to go back a page
// ! Although it appears that this doesn't work for Dojo textarea's, something to do
// with it using an inline frame that doesn't remember what was in it when the form 
// was submitted.
//
function mysaveback() {
	if (dirty) {
		dirty = false;
		if (document.q.jump_to)
			document.q.jump_to.value="";
		if (document.q.BACK2)
			document.q.BACK2.value="";
		n = saveevery;		// Reset the timer now
//		console.info("Sending data ");
		showoutput("Waiting for response from server...");

		// The parameters to pass to xhrPost, the form, how to handle it, and the callbacks.
		// Note that there isn't a url passed.  xhrPost will extract the url to call from the form's
		//'action' attribute.  You could also leave off the action attribute and set the url of the xhrPost object
		// either should work.
		var xhrArgs = {
		  form: dojo.byId("q"),
		  handleAs: "text",
		  load: function(data){
			if (dojo.byId("response"))
				dojo.byId("response").innerHTML = '<img src="/pix/206.greencheck.gif" align="top"> Saved.';
				window.history.go(-1);
			n = saveevery;		// Reset the timer now
		  },
		  error: function(error){
			// We'll 404 in the demo, but that's okay.  We don't have a 'postIt' service on the
				dojo.byId("response").innerHTML = "Error: "+error;
		  }
		}
		// Call the asynchronous xhrPost
		if (dojo.byId("response"))
			dojo.byId("response").innerHTML = '<img src="/pix/ajax-loader.gif" align="top"> Saving...';
		var deferred = dojo.xhrPost(xhrArgs);
	} else {
		window.history.go(-1);
	}
}
//
// This is a simple back button handler, for Q10A where we don't need save funtionality at the same time
//
function myback() {
	window.history.go(-1);
}
// End of subs
