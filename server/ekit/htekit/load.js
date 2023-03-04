// Common Javascript code for all DW ActiveX pages
// $Id: load.js,v 1.1 2008-04-22 01:46:10 triton Exp $
function loadme()
    {
    if (/*@cc_on!@*/!1)		// Is this IE ?
    	{
	    document.all("x").width = document.body.clientWidth;
    	document.all("x").height = document.body.clientHeight-20;
    	document.getElementById('warn').innerHTML = "";
    	document.getElementById('warn').style.display = "none";
    	}
    else
    	{
    	document.getElementById('warn').innerHTML = "<P>&nbsp;<P>I'm sorry! <P>You need Microsoft Internet Explorer to view this page properly<P> This page uses Microsoft's ActiveX technology, which is not supported by other browsers.";
    	}
    }
