#!/usr/bin/perl
# $Id: 360_updatep.pl,v 1.7 2012-11-01 03:29:48 triton Exp $
#
# Common code called by 360_editp.pl and pwikit_cms_par_import.pl
#
sub update_participant
	{
	my $debug = shift;
	&calc_ustuff;		# This lives in 360-lib.pl, and may be overridden by a sub in $config{case}_cfg.pl
	my %extras = ();
	$extras{'fullname'} = $ufields{fullname};
	$extras{'batchno'} = $ufields{batchno};
	&db_save_extras($config{index},$ufields{password},\%extras);
# Need to update all u-files for participant/boss/peer
# Need to update database as well : master is done
	for (my $k=1;$k<=$config{nboss};$k++)		# Boss emails
		{
		next if (($ufields{"bossfirstname$k"} eq '') 
					&& ($ufields{"bosslastname$k"} eq '') 
					&& ($ufields{"bossemail$k"} eq ''));
		$ufields{bossfullname} = mk_fullname($ufields{"bossfirstname$k"},$ufields{"bosslastname$k"});
		$ufields{bossfirstname} = $ufields{"bossfirstname$k"};
		$ufields{bosslastname} = $ufields{"bosslastname$k"};
		$ufields{bossemail} = $ufields{"bossemail$k"};
		if (($ufields{"bossfirstname$k"} ne '') || ($ufields{"bosslastname$k"} ne ''))
			{
			$ufields{"bossfullname$k"} = mk_fullname($ufields{"bossfirstname$k"},$ufields{"bosslastname$k"});
			$ufields{who} = $ufields{"bossfullname$k"};	# Save the name of the person filling in the form.
			}
		my $jobtitle = $ufields{jobtitle};
		my @mylist = @{$config{bosslist}};
		&debug("roles\->$jobtitle\->bosslist\[0\]=".$config{roles}{$jobtitle}{bosslist}[0]);
		if ($config{roles}{$jobtitle}{bosslist}[0] ne '')
			{
			@mylist = @{$config{roles}{$jobtitle}{bosslist}};
			}
		if ($ufields{"bosspassword$k"} eq '')	# No password - allocate one
			{
			&debug("Allocating new password for boss:[$ufields{bossfullname}]");
			$ufields{"bosspassword$k"} = &db_getnextpwd($config{master});
			&db_save_pwd_full($config{master},$ufields{id},$ufields{"bosspassword$k"},
						$ufields{"bossfullname$k"},0,$ufields{batchno},$ufields{"bossemail$k"});
			foreach my $survey_id (@mylist)
				{
				&db_new_survey($survey_id);		# Make sure the receiving table exists
				&db_save_pwd_full($survey_id,
							$ufields{id},
							$ufields{"bosspassword$k"},
							$ufields{"bossfullname$k"},
							0,
							$ufields{batchno},
							$ufields{"bossemail$k"});
				&db_add_invite($config{index},$config{case},$survey_id,
						$ufields{id},$ufields{"bosspassword$k"},
						$ufields{"bossfullname$k"},'Boss',
						$ufields{batchno});
				&debug("Saving new boss info for $survey_id");
				&save_ufile($survey_id,$ufields{"bosspassword$k"});
				}
			}
		else	# Not new - just update the ufiles
			{
			my %extras = ();
			$extras{fullname} = $ufields{"bossfullname$k"};
			$extras{email} = $ufields{"bossemail$k"};
			foreach my $survey_id (@mylist)
				{
				&debug("Updating boss $k info");
				&save_ufile($survey_id,$ufields{"bosspassword$k"});
				update_dfile($survey_id,$ufields{id},$ufields{"bosspassword$k"});
				&db_save_extras($survey_id,$ufields{"bosspassword$k"},\%extras);
				}
			}
		&debug("Saving boss changes to master");
		my %extras = ();
		$extras{'fullname'} = $ufields{"bossfullname$k"};
		$extras{'batchno'} = $ufields{batchno};
		&db_save_extras($config{index},$ufields{"bosspassword$k"},\%extras);
# ??? Do we really need to do this ?
		save_ufile($config{participant},$ufields{"bosspassword$k"});
		}
	for (my $k=1;$k<=$config{npeer};$k++)		# Peer emails
		{
		$ufields{who} = 'Santa Claus';
		next if (($ufields{"peerfirstname$k"} eq '') 
					&& ($ufields{"peerlastname$k"} eq '') 
					&& ($ufields{"peeremail$k"} eq ''));
		# AC says these individual names need to go into the ufile too. the peer email uses [%PEERFULLNAME%] and [%PEERFIRSTNAME%]
		# might as well do [%peerlastname%] while we are at it.
		$ufields{peerfullname} = mk_fullname($ufields{"peerfirstname$k"},$ufields{"peerlastname$k"});
		$ufields{peerfirstname} = $ufields{"peerfirstname$k"};
		$ufields{peerlastname} = $ufields{"peerlastname$k"};
		$ufields{peeremail} = $ufields{"peeremail$k"};
		if (($ufields{"peerfirstname$k"} ne '') || ($ufields{"peerlastname$k"} ne ''))
			{
			$ufields{"peerfullname$k"} = mk_fullname($ufields{"peerfirstname$k"},$ufields{"peerlastname$k"}) ;
			$ufields{who} = $ufields{"peerfullname$k"};	# Save the name of the person filling in the form.
			}
		my @mylist = @{$config{peerlist}};
		my $jobtitle = $ufields{jobtitle};
		&debug("roles\->$jobtitle\->peerlist\[0\]=".$config{roles}{$jobtitle}{peerlist}[0]);
		if ($config{roles}{$jobtitle}{peerlist}[0] ne '')
			{
			@mylist = @{$config{roles}{$jobtitle}{peerlist}};
			}
		if ($ufields{"peerpassword$k"} eq '')	# No password - allocate one
			{
			&debug("Allocating new password for peer:[$ufields{peerfullname}]");
			$ufields{"peerpassword$k"} = &db_getnextpwd($config{master});
			&db_save_pwd_full($config{master},$ufields{id},$ufields{"peerpassword$k"},
						$ufields{"peerfullname$k"},0,$ufields{batchno},$ufields{"peeremail$k"});
			foreach my $survey_id (@mylist)
				{
				&db_new_survey($survey_id);		# Make sure the receiving table exists
				&db_save_pwd_full($survey_id,$ufields{id},$ufields{"peerpassword$k"},$ufields{"peerfullname$k"},0,$ufields{batchno},$ufields{"peeremail$k"});
				&db_add_invite($config{index},$config{case},$survey_id,
						$ufields{id},$ufields{"peerpassword$k"},
						$ufields{"peerfullname$k"},'Peer',
						$ufields{batchno});
				&debug("Saving new peer info");
				&save_ufile($survey_id,$ufields{"peerpassword$k"});
				}
			}
		else	# Not new - just update the ufiles
			{
			my %extras = ();
			$extras{fullname} = $ufields{"peerfullname$k"};
			$extras{email} = $ufields{"peeremail$k"};
			foreach my $survey_id (@mylist)
				{
				&debug("Updating peer $k info");
				&save_ufile($survey_id,$ufields{"peerpassword$k"});
				update_dfile($survey_id,$ufields{id},$ufields{"peerpassword$k"});
				&db_save_extras($survey_id,$ufields{"peerpassword$k"},\%extras);
				}
			}
		&debug("Saving peer changes to master");
		my %extras = ();
		$extras{'fullname'} = $ufields{"peerfullname$k"};
		$extras{'batchno'} = $ufields{batchno};
		&db_save_extras($config{index},$ufields{"peerpassword$k"},\%extras);
# ??? Do we really need to do this ?
		save_ufile($config{participant},$ufields{"peerpassword$k"});
		}
	&debug("Saving changes to master");
	$ufields{who} = $ufields{fullname};	# Save the name of the person filling in the form.
	my @selflist = @{$config{selflist}};
	push @selflist,'MAP026';				# Force in MAP026 in case it's needed
	my $jobtitle = $ufields{jobtitle};
	&debug("roles\->$jobtitle\->selflist\[0\]=".$config{roles}{$jobtitle}{selflist}[0]);
	if ($config{roles}{$jobtitle}{selflist}[0] ne '')
		{
		@selflist = @{$config{roles}{$jobtitle}{selflist}};
		if ($ufields{new})							# New customer ?
			{
			push @selflist,@{$config{roles}{$jobtitle}{newlist}};			# Add newlist to this 1
			}
		}
	else
		{
		if ($ufields{new})							# New customer ?
			{
			push @selflist,@{$config{newlist}};			# Add newlist to this 1
			}
		}
	my %extras = ();
	foreach my $key (qw{fullname email})
		{
		$extras{$key} = $ufields{$key} if ($extras{$key} ne $ufields{$key});
		}
	foreach my $survey_id (@selflist)
		{
		print "Updating participant info for $survey_id, pwd=$ufields{password}\n" if ($debug);
		print Dumper \%ufields if ($debug);
		&save_ufile($survey_id,$ufields{password});
		&update_dfile($survey_id,$ufields{id},$ufields{password});
		&db_save_extras($survey_id,$ufields{password},\%extras) if (keys %extras);
		}
#---------???
# This save is probably redundant, as $config{participant} may not be 
# a form that they need to fill in. If we take this out, it means we have 
# to calculate the equivalent of $config{participant} when we pull in the
# participant's data earlier in the piece. This also applies when saving boss and peer changes
#
	&save_ufile($config{participant},$ufields{password});	# Get the boss/peer changes to the master
#---------
	&db_case_update_names($config{index},$ufields{id});
# Tell the user we are done:
	&add2body(<<HTML);
  <table width="80%" cellpadding="5" cellspacing="0" class="mytable">
    <tr class="heading"> 
      <td colspan="4" height="27"> 
        Database update completed: $cnt fields updated, $nem emails sent
      </td>
    </tr>
  </table>
HTML
	if ($config{status})
		{
		my $cmd = qq{perl ../scripts/pwikit_prime_status.pl -only=$ufields{id} $config{participant}};
		&add2body(qq{Updated participant status<BR><SPAN onclick="document.all.item('cmd_status').style.display = ''">+</SPAN><SPAN id='cmd_status' style="display:none">});
		&add2body(qq{Executing system cmd: $cmd </span>});
		my $res = `$cmd`;
		&add2body(" $res <BR>");
		}
	}
# We are good :)
1;
