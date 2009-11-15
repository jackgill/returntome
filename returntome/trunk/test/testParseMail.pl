#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use Mod::ParseMail;
use Test::More tests => 4;

Log::Log4perl::init('conf/log4perl_test.conf');

my @valid_mails;
my @invalid_mails;

my $mail;
my $message;

$mail = <<'EOF';
Date: Tue, 11 Aug 2009 18:52:29 -0600
Subject: subject line
From: Jack Gill <return.to.me.test@gmail.com>
To: return.to.me.receive@gmail.com

R2M: 8-11-09 8:18 pm
this is the body
    
EOF
    
$message = &parseMail($mail,'return.to.me.test@gmail.com');
ok(&fromEpoch($message->{return_time}) eq '21:18:00 08-11-2009','Not MIME');

$mail = <<'EOF';
Delivered-To: return.to.me.receive@gmail.com
Received: by 10.90.113.8 with SMTP id l8cs68634agc;
        Thu, 12 Nov 2009 20:44:07 -0800 (PST)
Return-Path: <return.to.me.test@gmail.com>
Received-SPF: pass (google.com: domain of return.to.me.test@gmail.com designates 10.216.90.138 as permitted sender) client-ip=10.216.90.138;
Authentication-Results: mr.google.com; spf=pass (google.com: domain of return.to.me.test@gmail.com designates 10.216.90.138 as permitted sender) smtp.mail=return.to.me.test@gmail.com; dkim=pass header.i=return.to.me.test@gmail.com
Received: from mr.google.com ([10.216.90.138])
        by 10.216.90.138 with SMTP id e10mr201998wef.150.1258087446688 (num_hops = 1);
        Thu, 12 Nov 2009 20:44:06 -0800 (PST)
DKIM-Signature: v=1; a=rsa-sha256; c=relaxed/relaxed;
        d=gmail.com; s=gamma;
        h=domainkey-signature:mime-version:received:date:message-id:subject
         :from:to:content-type;
        bh=00fK+bK0AKZEGYQYaup34XyawEB2xdja58oBEEXH2+o=;
        b=IoIaI5EDh6Xz109FIkezFE00KzcZ2AwCIn5c12rHuZezLZ+EDavA3qVeQQ0HQZMHWS
         Cvn27f76djYQZPObfyrujFIdW81PBkqhjHTjxkQSypQtJlx4WaRGUQhTVvmsDnHWK7Cb
         JqXfyqHRFFjEAiYOOOe7PpaRhG8OdY2s5tBj8=
DomainKey-Signature: a=rsa-sha1; c=nofws;
        d=gmail.com; s=gamma;
        h=mime-version:date:message-id:subject:from:to:content-type;
        b=psWom2n9YVRODPOv2uVUSfzWtk3yNZ8zR+WZqBTtFE7lDlnHeZTjIC4cjj5VEPeX5e
         jFsfCufi9OCTrp9xUqye+iKt8HY1zmSiBuHojxD0YQ4We0Vo48t2H9dzzfr8H4zg7Aro
         jHocjTFRrq0FtkhiQqJEWPatHSVmA8+cIHpk0=
MIME-Version: 1.0
Received: by 10.216.90.138 with SMTP id e10mr201998wef.150.1258087446683; Thu, 
	12 Nov 2009 20:44:06 -0800 (PST)
Date: Thu, 12 Nov 2009 21:44:06 -0700
Message-ID: <770830640911122044m73db6ae2re65fd67eb8472b3f@mail.gmail.com>
Subject: this is the subject line
From: Jack Gill <return.to.me.test@gmail.com>
To: return.to.me.receive@gmail.com
Content-Type: multipart/alternative; boundary=0016e6d99bed5b219c0478394fd8

--0016e6d99bed5b219c0478394fd8
Content-Type: text/plain; charset=ISO-8859-1

R2M: 8-11-09 8:18 pm

this is the body.

--0016e6d99bed5b219c0478394fd8
Content-Type: text/html; charset=ISO-8859-1

R2M: 8-11-09 8:18 pm<br><br>this is the body.<br><br>

EOF

$message = &parseMail($mail,'return.to.me.test@gmail.com');
ok(&fromEpoch($message->{return_time}) eq '21:18:00 08-11-2009','multipart/alternative');
#print $message->{parsed_mail};

$mail = <<'EOF';
Delivered-To: return.to.me.receive@gmail.com
Received: by 10.90.113.8 with SMTP id l8cs69375agc;
        Thu, 12 Nov 2009 21:01:36 -0800 (PST)
Return-Path: <return.to.me.test@gmail.com>
Received-SPF: pass (google.com: domain of return.to.me.test@gmail.com designates 10.216.87.136 as permitted sender) client-ip=10.216.87.136;
Authentication-Results: mr.google.com; spf=pass (google.com: domain of return.to.me.test@gmail.com designates 10.216.87.136 as permitted sender) smtp.mail=return.to.me.test@gmail.com; dkim=pass header.i=return.to.me.test@gmail.com
Received: from mr.google.com ([10.216.87.136])
        by 10.216.87.136 with SMTP id y8mr54826wee.43.1258088495781 (num_hops = 1);
        Thu, 12 Nov 2009 21:01:35 -0800 (PST)
DKIM-Signature: v=1; a=rsa-sha256; c=relaxed/relaxed;
        d=gmail.com; s=gamma;
        h=domainkey-signature:mime-version:received:date:message-id:subject
         :from:to:content-type;
        bh=OjEv7OjY4U3tHPHCgmhNwyZZd/a9z3QDXsT0Wx+tdqQ=;
        b=CuC7+v9EnwkvDUHA5858QQyPn/wrzNnBCNNhgMzoMk/slkLrL3Zy6FZ/waPzYaxdmD
         2v+SfNd8zGBJ9ONug917kAjtCvSS8qA15khA1T1nkRomcWE+39KVbuDA/9B8bCuOGqFn
         mTzZoT1BJXDRES+CsvGVwIrS+mDDnsq4W0Sng=
DomainKey-Signature: a=rsa-sha1; c=nofws;
        d=gmail.com; s=gamma;
        h=mime-version:date:message-id:subject:from:to:content-type;
        b=fYoXplMjCmQH0nXxe4wdw37ahrt527r0uZcfZJV0zIyM7OW/NSLEuhej4jH5DOwViT
         ImYYD8A8NQ/yonYwZ7kcUYQF/BhHxkCIC+rsoa1gGzzlLIidFPGTRG/4RnqMvoQfqsJd
         POa97Yh02uCYHroO0b/AgsGLyfYvuLFjge4as=
MIME-Version: 1.0
Received: by 10.216.87.136 with SMTP id y8mr54826wee.43.1258088495775; Thu, 12 
	Nov 2009 21:01:35 -0800 (PST)
Date: Thu, 12 Nov 2009 22:01:35 -0700
Message-ID: <770830640911122101h196e5697gf3602c89da2c33b4@mail.gmail.com>
Subject: this is the subject line
From: Jack Gill <return.to.me.test@gmail.com>
To: return.to.me.receive@gmail.com
Content-Type: multipart/mixed; boundary=0016e6d7ec28e304b30478398d78

--0016e6d7ec28e304b30478398d78
Content-Type: multipart/alternative; boundary=0016e6d7ec28e304ab0478398d76

--0016e6d7ec28e304ab0478398d76
Content-Type: text/plain; charset=ISO-8859-1

R2M: 8-11-09 8:18 pm

this is the body.

--0016e6d7ec28e304ab0478398d76
Content-Type: text/html; charset=ISO-8859-1

R2M: 8-11-09 8:18 pm<br><br>this is the body.<br><br>

--0016e6d7ec28e304ab0478398d76--
--0016e6d7ec28e304b30478398d78
Content-Type: text/plain; charset=US-ASCII; name="attachment.txt"
Content-Disposition: attachment; filename="attachment.txt"
Content-Transfer-Encoding: base64
X-Attachment-Id: f_g1yheagj0

dGhpcyBpcyBhIHRleHQgYXR0YWNobWVudC4Kb29oIGxhIGxhLgo=


EOF

$message = &parseMail($mail,'return.to.me.test@gmail.com');
ok(&fromEpoch($message->{return_time}) eq '21:18:00 08-11-2009','multipart/mixed');
#print $message->{parsed_mail};

$mail = <<'EOF';
Delivered-To: return.to.me.beta@gmail.com
Received: by 10.231.65.78 with SMTP id h14cs30913ibi;
        Thu, 12 Nov 2009 10:52:10 -0800 (PST)
Received: by 10.150.172.42 with SMTP id u42mr5828816ybe.349.1258051930020;
        Thu, 12 Nov 2009 10:52:10 -0800 (PST)
Return-Path: <Justin.McHenry@colorado.edu>
Received: from ipmx2.colorado.edu (ipmx2.colorado.edu [128.138.128.232])
        by mx.google.com with ESMTP id 23si1786409gxk.43.2009.11.12.10.52.09;
        Thu, 12 Nov 2009 10:52:09 -0800 (PST)
Received-SPF: pass (google.com: domain of Justin.McHenry@colorado.edu designates 128.138.128.232 as permitted sender) client-ip=128.138.128.232;
Authentication-Results: mx.google.com; spf=pass (google.com: domain of Justin.McHenry@colorado.edu designates 128.138.128.232 as permitted sender) smtp.mail=Justin.McHenry@colorado.edu
X-IronPort-Anti-Spam-Filtered: true
X-IronPort-Anti-Spam-Result: ApoEAKfn+0rAqBGb/2dsb2JhbADOagEJhhqIToI9FYFqBA
X-IronPort-AV: E=Sophos;i="4.44,729,1249279200"; 
   d="scan'208";a="141113567"
Received: from omr-raz-2-priv.int.colorado.edu ([192.168.17.155])
  by ipmx2-priv.int.colorado.edu with ESMTP; 12 Nov 2009 11:52:08 -0700
Received: from adx1.ad.colorado.edu (EHLO adx1.ad.colorado.edu) ([128.138.129.154])
	by omr-raz-2-priv.int.colorado.edu (MOS 3.10.4-GA FastPath queued)
	with ESMTP id BHA18014;
	Thu, 12 Nov 2009 11:52:07 -0700 (MST)
Received: from exfe1.int.colorado.edu ([128.138.129.206]) by adx1.ad.colorado.edu with Microsoft SMTPSVC(6.0.3790.3959);
	 Thu, 12 Nov 2009 11:52:07 -0700
Received: from rgnt175-194-dhcp.colorado.edu ([128.138.175.194]) by exfe1.int.colorado.edu over TLS secured channel with Microsoft SMTPSVC(6.0.3790.3959);
	 Thu, 12 Nov 2009 11:52:07 -0700
Content-Type: text/plain; charset=us-ascii
Mime-Version: 1.0 (Apple Message framework v1077)
Subject: =?iso-8859-1?Q?Fwd:_Reminder:_Apple_Education_Seminars_&_Events_?=
 =?iso-8859-1?Q?-_Tune-in_Series:_Mac=A0OS=A0X_Server_-_Client_Ma?=
 =?iso-8859-1?Q?nagement_and_Deployment?=
From: "Justin C. McHenry" <Justin.McHenry@Colorado.EDU>
X-Priority: 3
Date: Thu, 12 Nov 2009 11:52:07 -0700
Content-Transfer-Encoding: quoted-printable
Message-Id: <3E55ECC1-E1BA-46C4-BE8D-E0B59C9A8D4E@colorado.edu>
References: <20091111081503.601D325FA4D@app-4.insomnia.lan>
To: return.to.me.beta@gmail.com
X-Mailer: Apple Mail (2.1077)
X-OriginalArrivalTime: 12 Nov 2009 18:52:07.0827 (UTC) FILETIME=[3BEA5630:01CA63C9]

R2M Friday 7:55 AM
Justin McHenry | Administrative Desktop Support | Information Technology =
Services | University of Colorado at Boulder | Tel: 303.492.5662

Begin forwarded message:

> From: "Apple Education Seminars"<edcommunity@apple.com>
> Date: November 11, 2009 1:15:03 AM MST
> To: justin.mchenry@colorado.edu
> Subject: Reminder: Apple Education Seminars & Events - Tune-in Series: =
Mac OS X Server - Client Management and Deployment
> Reply-To: "Apple Education Seminars"<edcommunity@apple.com>
>=20
> You're registered to attend an upcoming event:
>=20
> Tune-in Series: Mac OS X Server - Client Management and Deployment - =
Online Event
> Friday, November 13 9:00AM to Friday, December 18 2009 10:00AM
>=20
> The Apple Tune-in Series is a collection of free webinars focused on =
introducing educators and IT leaders new to the Mac platform to the =
capabilities of the Mac OS X Snow Leopard operating system and Mac OS X =
Snow Leopard Server.
>=20
>=20
>=20
> You can review the full event at the following URL:
>=20
> 	http://edseminars.apple.com/event/2102/103326
>=20
> <p>Thank you for registering for the Tune-in webinar series.  No phone =
access is needed. To enter Friday's webinar, please follow the steps =
below:</p>
>=20
> <b>To join the online meeting</b>=20
> <ol>
> <li>Click the day and time link below about five to ten minutes prior =
to the start of the webinar. (The embedded URL will continue to work for =
the applicable time every Friday through December 18, 2009.)</li>
> <li><a href=3D"http://apple.na4.acrobat.com/osxsmanagement/">Fri. 9 =
a.m. PDT</a></li>
> <li>Click "Enter as a Guest" and type your first and last name</li>
> <li>Click "Enter Room"</li>
> </ol>
> <ul>
> <b>If you have never attended a Connect Pro meeting before:</b>
> <ol>
> <li>Test your connection: <a =
href=3D"http://apple.na4.acrobat.com/common/help/en/support/meeting_test.h=
tm">Click here</a></li>
> <li>Get a quick overview: <a =
href=3D"http://www.adobe.com/go/connectpro_overview">Click here</a></li>
> </ol>
>=20
> -Apple Education Seminars
>=20

EOF

$message = &parseMail($mail,'return.to.me.test@gmail.com');
ok(&fromEpoch($message->{return_time}) eq '','multipart/mixed');
print $message->{parsed_mail};
