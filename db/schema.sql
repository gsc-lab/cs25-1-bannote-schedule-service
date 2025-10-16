DROP DATABASE IF EXISTS ban_note_development;
CREATE DATABASE ban_note_development CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
USE ban_note_development;

-- =============================
-- 그룹 권한
-- =============================
CREATE TABLE `group_permission` (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,  -- PK는 id 단일키
    permission ENUM('우선1', '우선2', '우선3') NOT NULL,
    created_at DATETIME NULL,
    created_by INT NULL
);

-- =============================
-- 그룹
-- =============================
CREATE TABLE `group` (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,  -- PK 단일키
    group_type_id BIGINT NOT NULL,
    department_id BIGINT NULL,
    group_name VARCHAR(100) NOT NULL,
    group_description VARCHAR(500) NULL,
    is_public BOOLEAN NOT NULL,
    color_default VARCHAR(10) NOT NULL,
    color_highlight VARCHAR(10) NOT NULL,
    is_published BOOLEAN NOT NULL,
    created_at DATETIME NOT NULL,
    updated_at DATETIME NULL,
    deleted_at DATETIME NULL,
    created_by INT NULL,
    updated_by INT NULL,
    deleted_by INT NULL,
    FOREIGN KEY (group_type_id) REFERENCES `group_permission`(id)
);

-- =============================
-- 태그
-- =============================
CREATE TABLE `tag` (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(50) NOT NULL,
    created_at DATETIME NOT NULL,
    created_by INT NOT NULL
);

-- =============================
-- 그룹-태그 연결
-- =============================
CREATE TABLE `group_tag` (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    group_id BIGINT NOT NULL,
    tag_id BIGINT NOT NULL,
    FOREIGN KEY (group_id) REFERENCES `group`(id),
    FOREIGN KEY (tag_id) REFERENCES `tag`(id)
);

-- =============================
-- 사용자
-- =============================
CREATE TABLE `user` (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    default_group_id BIGINT NOT NULL,
    student_number VARCHAR(20) NOT NULL,
    name VARCHAR(20) NOT NULL,
    email VARCHAR(50) NOT NULL,
    department VARCHAR(30) NOT NULL,
    FOREIGN KEY (default_group_id) REFERENCES `group`(id)
);

-- =============================
-- 사용자-그룹 관계
-- =============================
CREATE TABLE `user_group` (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    group_id BIGINT NOT NULL,
    created_at DATETIME NOT NULL,
    FOREIGN KEY (group_id) REFERENCES `group`(id)
);

-- =============================
-- 그룹 편집자
-- =============================
CREATE TABLE `group_update` (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    group_id BIGINT NOT NULL,
    created_at DATETIME NOT NULL,
    FOREIGN KEY (group_id) REFERENCES `group`(id)
);

-- =============================
-- 일정 링크
-- =============================
CREATE TABLE `schedule_link` (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(100) NOT NULL,
    place_id INT NULL,
    description VARCHAR(500) NULL,
    place_text VARCHAR(20) NULL,
    start_time DATETIME NOT NULL,
    end_time DATETIME NOT NULL,
    is_allday BOOLEAN NOT NULL,
    created_at DATETIME NULL,
    updated_at DATETIME NULL,
    created_by INT NULL
);

-- =============================
-- 일정 파일
-- =============================
CREATE TABLE `schedule_file` (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    schedule_link_id BIGINT NOT NULL,
    created_by INT NOT NULL,
    created_at DATETIME NOT NULL,
    file_path VARCHAR(255) NOT NULL,
    FOREIGN KEY (schedule_link_id) REFERENCES `schedule_link`(id)
);

-- =============================
-- 일정
-- =============================
CREATE TABLE `schedule` (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    group_id BIGINT NOT NULL,
    schedule_link_id BIGINT NOT NULL,
    memo VARCHAR(255) NULL,
    color ENUM('default', 'important') NOT NULL,
    created_at DATETIME NOT NULL,
    updated_at DATETIME NULL,
    deleted_at DATETIME NULL,
    created_by INT NOT NULL,
    updated_by INT NULL,
    deleted_by INT NULL,
    FOREIGN KEY (group_id) REFERENCES `group`(id),
    FOREIGN KEY (schedule_link_id) REFERENCES `schedule_link`(id)
);
