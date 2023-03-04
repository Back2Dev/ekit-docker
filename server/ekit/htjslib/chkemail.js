// $Id: chkemail.js,v 1.1 2008-02-26 11:12:27 triton Exp $
// Javascript to validate an email address
//

function valid_email(str) 
    {
  // are regular expressions supported?
    var supported = 0;
    if (window.RegExp) 
        {
        var tempStr = "a";
        var tempReg = new RegExp(tempStr);
        if (tempReg.test(tempStr)) supported = 1;
        }
    if (!supported) 
        return (str.indexOf(".") > 2) && (str.indexOf("@") > 0);
    var r1 = new RegExp("(@.*@)|(\\.\\.)|(@\\.)|(^\\.)");
    var r2 = new RegExp("^.+\\@(\\[?)[a-zA-Z0-9\\-\\.]+\\.([a-zA-Z]{2,3}|[0-9]{1,3})(\\]?)$");
    return (!r1.test(str) && r2.test(str));
    }

