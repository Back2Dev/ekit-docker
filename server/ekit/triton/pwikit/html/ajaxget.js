var http;
function ajaxGet(myurl,destid)
  {
// Hang on to the destination array, which allows us not to have any references
// back to the calling code
  try
    {
    // Firefox, Opera 8.0+, Safari
    http = new XMLHttpRequest();
    }
  catch (e)
    {
    // Internet Explorer
    try
      {
      http = new ActiveXObject("Msxml2.XMLHTTP");
      }
    catch (e)
      {
      try
        {
        http = new ActiveXObject("Microsoft.XMLHTTP");
        }
      catch (e)
        {
        alert("I'm sorry, Your browser does not support AJAX!");
        return false;
        }
      }
    }
    http.onreadystatechange = handleResponse
    if (myurl == '')
    	{
    	alert("Missing URL in AjaxGet - aborting");
		}
    else
    	{
		http.open("POST", myurl, true);		
		//Send the proper header information along with the request
		http.setRequestHeader("Content-type", "application/x-www-form-urlencoded");
		http.setRequestHeader("Content-length", 0);
		http.setRequestHeader("Connection", "close");    	
	    http.send('');
    	}
	}

var stext = new Array("Ready","Loading","Loaded","Interactive","Complete");
function handleResponse() 
	{
//	alert("in handleResponse "+http.readyState);
   	log('handleResponse: '+stext[http.readyState]);
//    if(http.readyState == 3)	// Interactive - a problem was encountered
//    	{
//    	alert("Problem?:"+response);
//    	}
    if(http.readyState == 4)
    	{
        var response = http.responseText;
        if(response.indexOf('<') != -1) 			// Does the data look like HTML ?
        	{
	        logDebug("HTML Data returned: "+response);
	       	response = response.replace(/Content-type: text\/html/g,'');		// Trim out content type
	        showerr(response);
        	}
        else
        	{
// Call back the main application to draw the data :-
    		showme(response);
    		}
		}
	}


