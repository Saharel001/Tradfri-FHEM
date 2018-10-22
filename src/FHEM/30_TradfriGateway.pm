# @author Peter Kappelt
# @author Sebastian Kessler

# @version 1.18.2

package main;
use strict;
use warnings;

use Data::Dumper;
use JSON;

use TradfriIo;
 
sub TradfriGateway_Initialize($) {
	my ($hash) = @_;

	$hash->{DefFn}      = 'TradfriGateway_Define';
	$hash->{UndefFn}    = 'TradfriGateway_Undef';
	$hash->{SetFn}      = 'TradfriGateway_Set';
	$hash->{GetFn}      = 'TradfriGateway_Get';
	$hash->{ReadFn}     = 'TradfriGateway_Read';
	$hash->{WriteFn}	= 'TradfriGateway_Write';
	$hash->{ReadyFn}	= 'TradfriGateway_Ready';

	$hash->{Clients}	= "TradfriDevice:TradfriGroup";
	$hash->{MatchList} = {
			"1:TradfriDevice" => '^subscribedDeviceUpdate::',
			"2:TradfriGroup" => '(^subscribedGroupUpdate::)|(^moodList::)' ,
			};
}

sub TradfriGateway_Define($$) {
	my ($hash, $def) = @_;
	my @param = split('[ \t]+', $def);
	
	if(int(@param) < 3) {
		return "too few parameters: define <name> TradfriGateway <jTradfrie-ip:port>";
	}
	
	$hash->{name}  = $param[0];
	
	if ($param[2] =~ /\b(\d{1,3}(?:\.\d{1,3}){3}:\d{1,5})\b/) {
		$hash->{DeviceName} = $param[2];
	}else {
		return "Invalid parameters: define <name> TradfriGateway <jTradfrie-ip:port> like 192.168.178.100:1505";
	}
				
	#close connection to socket, if open
	DevIo_CloseDev($hash) if(DevIo_IsOpen($hash));  
	
	#open the socket connection
	DevIo_OpenDev($hash, 0, "TradfriGateway_DeviceInit");
}

sub TradfriGateway_Undef($$) {
	my ($hash, $arg) = @_; 
	  
	# close the connection 
	DevIo_CloseDev($hash);
	
	return undef;
}

sub TradfriGateway_DeviceInit($){
	my $hash = shift;

	#subscribe to all devices and groups, update the moodlist of the group
	#@todo check, whether we this instance is the IODev of the device/ group
	foreach my $deviceID ( keys %{$modules{'TradfriDevice'}{defptr}}){
		TradfriGateway_Write($hash, 0, 'subscribe', $deviceID);
	}

	foreach my $groupID ( keys %{$modules{'TradfriGroup'}{defptr}}){
		TradfriGateway_Write($hash, 1, 'subscribe', $groupID);
		TradfriGateway_Write($hash, 1, 'moodlist', $groupID);
	}
}


# a write command, that is dispatch from the logical module to here via IOWrite requires at least two arguments:
# - 1. Scope: 				Group (1) or Device (0)
# - 2. Action	: 			A command:
#								* list -> sets the readings groups/ devices
#								* moodlist (groups only) -> get all moods that are defined for this group
#								* subscribe -> subscribe to updated of that specific device
#								* set -> write a specific value to the group/ device
# - 3. ID:					ID of the group or device
# - 4. attribute::value		only for command set, attribute can be onoff, dimvalue, mood (groups only), color (devices only) or name
sub TradfriGateway_Write ($@){
	my ( $hash, $groupOrDevice, $action, $id, $attrValue) = @_;
	
	if(!defined($groupOrDevice) && !defined($action)){
		Log(1, "[TradfriGateway] Not enough arguments for IOWrite!");
		return "Not enough arguments for IOWrite!";
	}

	my $command = '';

	#for cmd-buildup: decide on group/ device
	if($groupOrDevice){
		$command .= 'group::';
	}else{
		$command .= 'device::';
	}

	if($action eq 'list'){
		$command .= 'list';
	}elsif($action eq 'moodlist'){
		$command .= "moodlist::${id}";
	}elsif($action eq 'subscribe'){
		#silently return if connection is open.
		#at startup, every device/ group runs subscribe. If the connection isn't open, we do it later.
		return if($hash->{STATE} ne 'opened');
		$command .= "subscribe::${id}";
	}elsif($action eq 'set'){
		$command .= "set::${id}::${attrValue}";
	}else{
		return "Unknown command: " . $command;
	}

	#Check if open with DevIO
	if(!DevIo_IsOpen($hash)){
		Log(1, "TradfriGateway: Can't write, connection is not opened!");
		return "Can't write, connection is not opened!";
	}
	#return DevIo_Expect($hash, $command . "\n", 1);
	DevIo_SimpleWrite($hash, $command . "\n", 2, 0);

	return undef;
}

#data was received on the socket
sub TradfriGateway_Read ($){
	my ( $hash ) = @_;

	my $msg = DevIo_SimpleRead($hash);	

	if(!defined($msg)){
		return undef;
	}

	my $msgReadableWhitespace = $msg;
	$msgReadableWhitespace =~ s/\r/\\r/g;
	$msgReadableWhitespace =~ s/\n/\\n/g;
	Log(4, "[TradfriGateway] Received message on socket: \"" . $msgReadableWhitespace . "\"");

	#there might be multiple messages at once, they are split by newline. Iterate through each of them
	my @messagesSingle = split(/\n/, $msg);
	foreach my $message(@messagesSingle){
		#if there is whitespace left, remove it.
		$message =~ s/\r//g;
		$message =~ s/\n//g;

		#devices and groups
		#@todo not as JSON array
		if(($message ne '') && ((split(/::/, $message))[0] =~ /(?:group|device)List/)){
			my @newmsg = split(/::/, $message);
			my $returnstring ="";
			#parse the JSON data
			my $jsonData = eval{ JSON->new->utf8->decode($newmsg[1]) };
			if($@){
				Log 3, "TradfriGateway: - ".$newmsg[1]." - can't be eval as JSON";
				return undef; #the string was probably not valid JSON
			}
			if($newmsg[0] eq 'deviceList'){
				my @items = @{ $jsonData };
				foreach my $item ( @items ) { 
					$returnstring = $returnstring.$item->{'deviceid'}." => ".$item->{'name'}."\n";
				}
				return readingsSingleUpdate($hash, 'devices', $returnstring, 1);
			}
			if($newmsg[0] eq 'groupList'){
				my @items = @{ $jsonData };
				foreach my $item ( @items ) { 
					$returnstring = $returnstring.$item->{'groupid'}." => ".$item->{'name'}."\n";
				}
				return readingsSingleUpdate($hash, 'groups', $returnstring, 1);
			}
		}

		#dispatch the message if it isn't empty, only dispatch messages that come from an observe
		if(($message ne '') && ((split(/::/, $message))[0] =~ /(?:subscribed(?:Group|Device)Update)|(?:moodList)/)){
			Dispatch($hash, $message, undef);
		}
	}
}

sub TradfriGateway_Ready($){
	my ($hash) = @_;
	return DevIo_OpenDev($hash, 1, "TradfriGateway_DeviceInit") if($hash->{STATE} eq "disconnected");
}

sub TradfriGateway_Get($@) {	
	my ( $hash, $name, $opt, @args ) = @_;

	return "\"get $name\" needs at least one argument" unless(defined($opt));

	if($opt eq 'deviceList'){
		return TradfriGateway_Write($hash, 0, 'list');
	}elsif($opt eq 'groupList'){
		return TradfriGateway_Write($hash, 1, 'list');
	}else {
		return "Unknown argument $opt, choose one of deviceList:noArg groupList:noArg";
	}
}

sub TradfriGateway_Set($@) {
	my ($hash, $name, $cmd) = @_;
	
	return "\"set $name\" needs at least one argument" unless(defined($cmd));

	if($cmd eq "reopen"){
		if(DevIo_IsOpen($hash)){
			#close connection to socket, if open			
			DevIo_CloseDev($hash);
			Log 3, "TradfriGateway: Disconnect from  ".$hash->{DeviceName};
		}
		#@todo react to return code
		DevIo_OpenDev($hash, 0, "TradfriGateway_DeviceInit");
		
	}else{
		return "unknown argument $cmd, choose one of reopen:noArg";
	}
}

1;

=pod

=item device
=item summary connects with an IKEA Trådfri gateway 
=item summary_DE stellt die Verbindung mit einem IKEA Trådfri Gateway her

=begin html

<a name="TradfriGateway"></a>
<h3>TradfriGateway</h3>
<ul>
    <i>TradfriGateway</i> stores the connection data for an IKEA Trådfri gateway. It is necessary for TradfriDevice and TradfriGroup
    <br><br>
    <a name="TradfriGatewaydefine"></a>
    <b>Define</b>
    <ul>
        <code>define &lt;name&gt; TradfriGateway &lt;gateway-ip&gt; &lt;gateway-secret&gt;</code>
        <br><br>
        Example: <code>define trGateway TradfriGateway TradfriGW.int.kappelt.net vBkxxxxxxxxxx7hz</code>
        <br><br>
        The IP can either be a "normal" IP-Address, like 192.168.2.60, or a DNS name (like shown above).<br>
        You can find the secret on a label on the bottom side of the gateway.
        The parameter "coap-client-path" is isn't used anymore and thus not shown here anymore. Please remove it as soon as possible, if you are still using it.<br>
		You need to run kCoAPSocket running in background, that acts like a translator between FHEM and the Trådfri Gateway.
    </ul>
    <br>
    
    <a name="TradfriGatewayset"></a>
    <b>Set</b><br>
    <ul>
        <code>set &lt;name&gt; &lt;option&gt; [&lt;value&gt;]</code>
        <br><br>
        You can set the following options. See <a href="http://fhem.de/commandref.html#set">commandref#set</a> 
        for more info about the set command.
        <br><br>
        Options:
        <ul>
              <li><i>reopen</i><br>
                  Re-open the connection to the Java TCP socket, that acts like a "translator" between FHEM and the Tradfri-CoAP-Infrastructure.<br>
                  If the connection is already opened, it'll be closed and opened.<br>
                  If the connection isn't open yet, a try to open it will be executed.<br>
                  <b>Caution: </b>Running this command seems to trigger some issues! Do <i>not</i> run it before a update is available!</li>
        </ul>
    </ul>
    <br>

    <a name="TradfriGatewayget"></a>
    <b>Get</b><br>
    <ul>
        <code>get &lt;name&gt; &lt;option&gt;</code>
        <br><br>
        You can get the following information about the device. See 
        <a href="http://fhem.de/commandref.html#get">commandref#get</a> for more info about 
        the get command.
		<br><br>
        Options:
        <ul>
              <li><i>deviceList</i><br>
                  Sets the reading "devices" to a JSON-formatted string of all device IDs and their names.</li>
              <li><i>groupList</i><br>
                  Sets the reading "devices" to a JSON-formatted string of all group IDs and their names.</li>
        </ul>
    </ul>
    <br>
    
    <a name="TradfriGatewayattr"></a>
    <b>Attributes</b>
    <ul>
        <code>attr &lt;name&gt; &lt;attribute&gt; &lt;value&gt;</code>
        <br><br>
        See <a href="http://fhem.de/commandref.html#attr">commandref#attr</a> for more info about 
        the attr command.
        <br><br>
        Attributes:
        <ul>
            <li><i></i><br>
            	There are no custom attributes implemented
            </li>
        </ul>
    </ul>
</ul>

=end html

=cut
