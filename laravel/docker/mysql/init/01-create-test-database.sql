CREATE DATABASE IF NOT EXISTS interntrack_test
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

GRANT ALL PRIVILEGES ON interntrack_test.* TO 'interntrack_user'@'%';

FLUSH PRIVILEGES;
