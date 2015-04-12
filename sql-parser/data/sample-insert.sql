-- MySQL dump 10.13  Distrib 5.5.31, for debian-linux-gnu (x86_64)
--
-- Host: 10.64.32.22    Database: enwiki
-- ------------------------------------------------------
-- Server version       5.5.30-MariaDB-mariadb1~precise-log

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `categorylinks`
--

DROP TABLE IF EXISTS `categorylinks`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `categorylinks` (
  `cl_from` int(8) unsigned NOT NULL DEFAULT '0',
  `cl_to` varbinary(255) NOT NULL DEFAULT '',
  `cl_sortkey` varbinary(230) NOT NULL DEFAULT '',
  `cl_timestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `cl_sortkey_prefix` varbinary(255) NOT NULL DEFAULT '',
  `cl_collation` varbinary(32) NOT NULL DEFAULT '',
  `cl_type` enum('page','subcat','file') NOT NULL DEFAULT 'page',
  UNIQUE KEY `cl_from` (`cl_from`,`cl_to`),
  KEY `cl_timestamp` (`cl_to`,`cl_timestamp`),
  KEY `cl_collation` (`cl_collation`),
  KEY `cl_sortkey` (`cl_to`,`cl_type`,`cl_sortkey`,`cl_from`)
) ENGINE=InnoDB DEFAULT CHARSET=binary;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `categorylinks`
--

/*!40000 ALTER TABLE `categorylinks` DISABLE KEYS */;
INSERT INTO `categorylinks` VALUES (10,'Redirects_with_old_history','ACCESSIBLECOMPUTING','2010-08-26 22:38:36','','uppercase','page'),(10,'Unprintworthy_redirects','ACCESSIBLECOMPUTING','2010-08-26 22:38:36','','uppercase','page'),(12,'All_NPOV_disputes','ANARCHISM','2013-09-27 13:38:38','','uppercase','page'),(12,'Anarchism',' \nANARCHISM','2010-09-03 21:55:38',' ','uppercase','page'),(12,'Anti-capitalism','ANARCHISM','2012-08-13 12:09:07','','uppercase','page'),(12,'Anti-fascism','ANARCHISM','2011-05-23 04:16:34','','uppercase','page'),(12,'Articles_containing_Ancient_Greek-language_text','ANARCHISM','2013-06-17 04:28:02','','uppercase','page'),(12,'Articles_containing_Spanish-language_text','ANARCHISM','2013-06-17 04:28:02','','uppercase','page'),(12,'Articles_with_French-language_external_links','ANARCHISM','2013-06-17 04:28:02','','uppercase','page'),(12,'Articles_with_inconsistent_citation_formats','ANARCHISM','2013-09-27 13:38:38','','uppercase','page'),(12,'Good_articles','ANARCHISM','2011-07-19 10:52:41','','uppercase','page'),(12,'NPOV_disputes_from_September_2013','ANARCHISM','2013-09-27 15:52:47','','uppercase','page'),(12,'Political_culture','ANARCHISM','2009-05-20 17:50:53','','uppercase','page'),(12,'Political_ideologies','ANARCHISM','2009-05-20 17:50:53','','uppercase','page'),(12,'Social_theories','ANARCHISM','2009-06-03 21:40:01','','uppercase','page'),(12,'Wikipedia_indefinitely_move-protected_pages','ANARCHISM\nANARCHISM','2013-02-08 05:50:46','Anarchism','uppercase','page'),(12,'Wikipedia_pages_protected_due_to_dispute','ANARCHISM\nANARCHISM','2013-09-28 02:08:57','Anarchism','uppercase','page'),(12,'Wikipedia_protected_pages_without_expiry','ANARCHISM\nANARCHISM','2013-09-28 02:08:57','Anarchism','uppercase','page'),(13,'Redirects_with_old_history','AFGHANISTANHISTORY','2007-04-19 22:12:13','','uppercase','page'),(13,'Unprintworthy_redirects','AFGHANISTANHISTORY','2006-09-08 04:15:52','','uppercase','page'),(14,'Redirects_with_old_history','AFGHANISTANGEOGRAPHY','2007-04-19 22:12:13','','uppercase','page'),(14,'Unprintworthy_redirects','AFGHANISTANGEOGRAPHY','2006-09-08 04:15:36','','uppercase','page'),(15,'Redirects_with_old_history','AFGHANISTANPEOPLE','2007-04-19 22:12:13','','uppercase','page'),(15,'Unprintworthy_redirects','AFGHANISTANPEOPLE','2006-09-08 04:15:11','','uppercase','page'),(18,'Redirects_with_old_history','AFGHANISTANCOMMUNICATIONS','2007-04-19 22:12:14','','uppercase','page'),(18,'Unprintworthy_redirects','AFGHANISTANCOMMUNICATIONS','2006-09-08 04:14:42','','uppercase','page'),(19,'Redirects_with_old_history','AFGHANISTANTRANSPORTATIONS','2007-04-19 22:12:14','','uppercase','page'),(19,'Unprintworthy_redirects','AFGHANISTANTRANSPORTATIONS','2006-09-08 04:14:07','','uppercase','page'),(20,'Redirects_with_old_history','AFGHANISTANMILITARY','2007-04-19 22:12:14','','uppercase','page'),(20,'Unprintworthy_redirects','AFGHANISTANMILITARY','2006-09-08 04:13:27','','uppercase','page'),(21,'Redirects_with_old_history','AFGHANISTANTRANSNATIONALISSUES','2007-04-19 22:12:14','','uppercase','page'),(21,'Unprintworthy_redirects','AFGHANISTANTRANSNATIONALISSUES','2006-04-01 12:08:42','','uppercase','page'),(23,'Redirects_with_old_history','ASSISTIVETECHNOLOGY','2007-04-19 22:12:14','','uppercase','page'),(23,'Unprintworthy_redirects','ASSISTIVETECHNOLOGY','2006-09-08 04:17:00','','uppercase','page'),(24,'Redirects_with_old_history','AMOEBOIDTAXA','2007-04-19 22:12:14','','uppercase','page'),(24,'Unprintworthy_redirects','AMOEBOIDTAXA','2006-09-08 04:17:51','','uppercase','page'),(25,'All_articles_containing_potentially_dated_statements','AUTISM','2013-08-30 03:22:57','','uppercase','page'),(25,'Articles_containing_potentially_dated_statements_from_2012','AUTISM','2013-08-30 03:22:57','','uppercase','page'),(25,'Autism',' \nAUTISM','2011-05-26 16:15:58',' ','uppercase','page'),(25,'Communication_disorders','AUTISM','2011-05-26 16:15:58','','uppercase','page'),(25,'Featured_articles','AUTISM','2011-07-19 10:12:06','','uppercase','page'),(25,'Learning_disabilities','AUTISM','2012-03-04 08:31:09','','uppercase','page'),(25,'Mental_and_behavioural_disorders','AUTISM','2011-08-16 08:00:48','','uppercase','page'),(25,'Neurological_disorders','AUTISM','2011-05-26 16:15:58','','uppercase','page'),(25,'Neurological_disorders_in_children','AUTISM','2011-05-26 16:15:58','','uppercase','page'),(25,'Pervasive_developmental_disorders','AUTISM','2011-05-26 16:15:58','','uppercase','page'),(25,'Psychiatric_diagnosis','AUTISM','2012-03-04 08:30:40','','uppercase','page'),(25,'Use_dmy_dates_from_June_2013','AUTISM','2013-08-30 03:22:57','','uppercase','page'),(25,'Wikipedia_indefinitely_move-protected_pages','AUTISM\nAUTISM','2013-08-30 03:22:57','Autism','uppercase','page'),(25,'Wikipedia_indefinitely_semi-protected_pages','AUTISM\nAUTISM','2013-08-30 03:22:57','Autism','uppercase','page'),(27,'Redirects_with_old_history','ALBANIAHISTORY','2007-04-19 22:12:14','','uppercase','page'),(27,'Unprintworthy_redirects','ALBANIAHISTORY','2006-09-08 04:18:56','','uppercase','page'),(29,'Redirects_with_old_history','ALBANIAPEOPLE','2007-04-19 22:12:14','','uppercase','page'),(29,'Unprintworthy_redirects','ALBANIAPEOPLE','2006-09-08 04:17:12','','uppercase','page'),(30,'Redirects_with_old_history','ASWEMAYTHINK','2007-04-19 22:12:15','','uppercase','page'),(30,'Unprintworthy_redirects','ASWEMAYTHINK','2006-09-08 04:19:17','','uppercase','page'),(35,'Redirects_with_old_history','ALBANIAGOVERNMENT','2007-04-19 22:12:15','','uppercase','page'),(35,'Unprintworthy_redirects','ALBANIAGOVERNMENT','2006-09-08 04:19:45','','uppercase','page'),(36,'Redirects_with_old_history','ALBANIAECONOMY','2007-04-19 22:12:15','','uppercase','page'),(36,'Unprintworthy_redirects','ALBANIAECONOMY','2006-09-08 04:19:59','','uppercase','page'),(39,'All_articles_with_unsourced_statements','ALBEDO','2013-09-23 19:32:47','','uppercase','page'),(39,'Articles_with_unsourced_statements_from_July_2013','ALBEDO','2013-09-23 19:32:47','','uppercase','page'),(39,'Climate_forcing','ALBEDO','2010-09-28 15:22:44','','uppercase','page'),(39,'Climatology','ALBEDO','2010-09-28 15:22:44','','uppercase','page'),(39,'Electromagnetic_radiation','ALBEDO','2010-09-28 15:22:44','','uppercase','page'),(39,'Pages_using_citations_with_old-style_implicit_et_al.','ALBEDO','2013-09-23 19:32:47','','uppercase','page'),(39,'Radiation','ALBEDO','2011-12-15 17:28:04','','uppercase','page'),(39,'Radiometry','ALBEDO','2010-09-28 15:22:44','','uppercase','page'),(39,'Scattering,_absorption_and_radiative_transfer_(optics)','ALBEDO','2010-09-28 15:22:44','','uppercase','page'));
