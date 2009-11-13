#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use Mod::ParseMail;
use Test::More tests => 3;

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
