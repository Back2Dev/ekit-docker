// $Id: dw_db_get.js,v 1.1 2008-02-27 11:31:37 triton Exp $
var http;
var tgt;
function ajaxGet(myurl,params,dest)
  {
// Hang on to the destination array, which allows us not to have any references
// back to the calling code
  tgt = dest;
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
        alert("Your browser does not support AJAX!");
        return false;
        }
      }
    }
    http.onreadystatechange = handleResponse
    if (myurl == '')
    	{
        http.open("GET","ajax.txt",true);
	    http.send(null);
		}
    else
    	{
		http.open("POST", myurl, true);		
		//Send the proper header information along with the request
		http.setRequestHeader("Content-type", "application/x-www-form-urlencoded");
		http.setRequestHeader("Content-length", params.length);
		http.setRequestHeader("Connection", "close");    	
	    http.send(params);
    	}
	}

var stext = new Array("Ready","Loading","Loaded","Interactive","Complete");
function handleResponse() 
	{
//	alert("in handleResponse "+http.readyState);
   	document.getElementById("chartdiv").innerHTML += stext[http.readyState]+'...';
//    if(http.readyState == 3)	// Interactive - a problem was encountered
//    	{
//    	alert("Problem?:"+response);
//    	}
    if(http.readyState == 4)
    	{
        var response = http.responseText;
        if(response.indexOf('<') != -1) 			// Does the data look like HTML ?
        	{
//	        alert("HTML Data returned: "+response);
	        showerr(response);
        	}
        else
        	{
	       	response = response.replace(/\r/g,'');		// Trim out DOS CR
	       	response = response.replace(/\n$/g,'');		// Trim blank trailing line
	        if(response.indexOf('\n') != -1) 
	        	{
	            var lines = response.split(/\n/);
	            for (i=0;i<lines.length;i++)
	            	{
//	            	alert("Line ["+i+"] = "+lines[i]); 
	           		if (lines[i] == '')
	            		continue;
			        if(lines[i].indexOf('\t') != -1) 
			        	{
//		           		alert ("Line "+i+' = ['+lines[i]+']');
			            var update = lines[i].split('	');
			            update[0] = update[0].replace(/=/g,'--');
// Save the response data in the target array object
			            tgt[update[0]] = update[1];
// Probably redundant, but if there are matching named elements, update them directly"
			            if (document.getElementById(update[0]))
			            	{
				            document.getElementById(update[0]).innerHTML = update[1];
					        }
			        	}
			        }
			    }
// Tell the world we are done fetching
	    	document.getElementById("chartdiv").innerHTML += ' - Got data (status='+http.status+'), updating chart now...<br>'+response;
// Call back the main application to draw the data :-
    		showme();
    		}
		}
	}
function showCache(cache)
	{
	var buf = '';
	for (var i in cache)
		{
		buf += i+" = "+cache[i]+"<BR>";
		}
	if (buf != '')
		document.getElementById("cache").innerHTML = buf;
	}
