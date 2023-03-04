<html>
 <head>
 <title> PHP Test Script </title>
 </head>
 <body>
<?php
phpinfo( );
if (json_encode("This is some random text xxx")) echo "OK"; else echo "Failed";
        if (function_exists('curl_init')) {
            echo "curl ok";
        } else {
            print "curl not found\n";
        }


?>
 </body>
 </html>
