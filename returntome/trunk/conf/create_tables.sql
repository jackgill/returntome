--On the command line:
-- mysql -u root -p ReturnToMe < conf/create_tables.sql

--To reset DB:
--TRUNCATE TABLE Messages;

--Drop tables:
DROP TABLE IF EXISTS RawMail;
DROP TABLE IF EXISTS ParsedMail;
DROP TABLE IF EXISTS Messages;

--Create tables:
CREATE TABLE Messages 
(
       uid INTEGER(9) ZEROFILL NOT NULL AUTO_INCREMENT,  
       address VARCHAR(320) NULL,
       received_time DATETIME NOT NULL,
       return_time DATETIME NULL, 
       sent_time DATETIME NULL,
       PRIMARY KEY (uid)
) ENGINE = InnoDB; 

CREATE TABLE RawMail 
(
	uid INTEGER(9) ZEROFILL NOT NULL,
    	mail MEDIUMBLOB NOT NULL, 
    	PRIMARY KEY (uid),
    	FOREIGN KEY (uid) REFERENCES Messages (uid)
    		ON DELETE CASCADE
    		ON UPDATE NO ACTION
) ENGINE = InnoDB;

CREATE TABLE ParsedMail 
(
	uid INTEGER(9) ZEROFILL NOT NULL,
    	mail MEDIUMBLOB NOT NULL, 
    	PRIMARY KEY (uid),
    	FOREIGN KEY (uid) REFERENCES Messages (uid)
    		ON DELETE CASCADE
    		ON UPDATE NO ACTION
) ENGINE = InnoDB;

CREATE TABLE Archive
(
       uid INTEGER(9) ZEROFILL NOT NULL,  
       address VARCHAR(320) NULL,
       received_time DATETIME NOT NULL,
       return_time DATETIME NULL, 
       sent_time DATETIME NULL,
       raw_mail MEDIUMBLOB NOT NULL,
       parsed_mail MEDIUMBLOB NOT NULL,
       PRIMARY KEY (uid),
       INDEX (sent_time)
) ENGINE = InnoDB;