/* TV4 (MySQL): khong co table-valued parameter (TVP) nhu SQL Server.
   Danh sach phong / lo su dung duoc truyen qua tham so JSON va doc bang JSON_TABLE
   trong 03_Transactions_TV4_VuTrungHieu.sql. File nay chi kiem tra phien ban MySQL. */
USE QLToaNha_BCNF;

SELECT IF(VERSION() >= '8.0.16',
    'TV4: MySQL dat yeu cau (>= 8.0.16), dung JSON_TABLE va CHECK constraint; khong can tao kieu du lieu.',
    'TV4: CAN MySQL >= 8.0.16 (JSON_TABLE va CHECK constraint).') AS KetQua;
