-- StudyTrace MySQL schema (based on database.tex manual SQL, extended for app coverage)

-- 1. User
create table `User` (
    UserID int auto_increment primary key,
    Username varchar(50) not null,
    Password varchar(255) not null,
    AvatarUrl varchar(255),
    Signature varchar(255),
    StreakDays int default 0,
    TotalPoints int default 0,
    CreatedAt timestamp default current_timestamp,
    UpdatedAt timestamp default current_timestamp on update current_timestamp
) engine=InnoDB default charset=utf8mb4;

-- 2. Study group
create table StudyGroup (
    GroupID int auto_increment primary key,
    GroupName varchar(50) not null,
    InviteCode varchar(10) not null,
    CreatedAt timestamp default current_timestamp
) engine=InnoDB default charset=utf8mb4;

-- 3. Group member
create table GroupMember (
    UserID int not null,
    GroupID int not null,
    JoinDate date default (CURRENT_DATE),
    Role enum('ADMIN', 'MEMBER') default 'MEMBER',
    primary key (UserID, GroupID),
    foreign key (UserID) references `User`(UserID) on delete cascade,
    foreign key (GroupID) references StudyGroup(GroupID) on delete cascade
) engine=InnoDB default charset=utf8mb4;

-- 4. Course
create table Course (
    CourseID int auto_increment primary key,
    CourseName varchar(50) not null,
    UserID int not null,
    CreatedAt timestamp default current_timestamp,
    UpdatedAt timestamp default current_timestamp on update current_timestamp,
    DeletedAt timestamp,
    foreign key (UserID) references `User`(UserID) on delete cascade
) engine=InnoDB default charset=utf8mb4;

-- 5. Study task
create table StudyTask (
    TaskID int auto_increment primary key,
    Title varchar(100) not null,
    TaskType enum(
        'CLASS_HOMEWORK',
        'PAPER_READING',
        'PROGRAMMING_HOMEWORK',
        'LAB_REPORT',
        'PROJECT_DEV',
        'EXAM_REVIEW',
        'READING_NOTES',
        'OTHER'
    ) default 'OTHER',
    Deadline timestamp not null,
    ReminderTime timestamp,
    Status enum('NOT_STARTED', 'IN_PROGRESS', 'COMPLETED') default 'NOT_STARTED',
    Note varchar(255) default '',
    CourseID int not null,
    UserID int not null,
    CreatedAt timestamp default current_timestamp,
    UpdatedAt timestamp default current_timestamp on update current_timestamp,
    DeletedAt timestamp,
    foreign key (CourseID) references Course(CourseID) on delete cascade,
    foreign key (UserID) references `User`(UserID) on delete cascade
) engine=InnoDB default charset=utf8mb4;

-- 6. Sub task
create table SubTask (
    SubTaskID int auto_increment primary key,
    Content varchar(255) not null,
    StartAt timestamp,
    Deadline timestamp not null,
    Status enum('NOT_STARTED', 'IN_PROGRESS', 'COMPLETED') default 'NOT_STARTED',
    Note varchar(255) default '',
    TaskID int not null,
    CreatedAt timestamp default current_timestamp,
    UpdatedAt timestamp default current_timestamp on update current_timestamp,
    DeletedAt timestamp,
    foreign key (TaskID) references StudyTask(TaskID) on delete cascade
) engine=InnoDB default charset=utf8mb4;

-- 7. Study log
create table StudyLog (
    LogID int auto_increment primary key,
    MainContent text,
    Problem text,
    Thoughts text,
    NextPlan text,
    Duration int,
    RecordDate date default (CURRENT_DATE),
    CourseID int not null,
    UserID int not null,
    CreatedAt timestamp default current_timestamp,
    UpdatedAt timestamp default current_timestamp on update current_timestamp,
    DeletedAt timestamp,
    foreign key (CourseID) references Course(CourseID) on delete cascade,
    foreign key (UserID) references `User`(UserID) on delete cascade
) engine=InnoDB default charset=utf8mb4;

-- 8. Flashcard
create table Flashcard (
    CardID int auto_increment primary key,
    Question text not null,
    Answer text not null,
    Hint varchar(255) default '',
    IsFavorite tinyint(1) default 0,
    IsStarred tinyint(1) default 0,
    GroupName varchar(50) default '',
    SourceType enum('AI', 'MANUAL') default 'MANUAL',
    CourseID int not null,
    UserID int not null,
    CreatedAt timestamp default current_timestamp,
    UpdatedAt timestamp default current_timestamp on update current_timestamp,
    DeletedAt timestamp,
    foreign key (CourseID) references Course(CourseID) on delete cascade,
    foreign key (UserID) references `User`(UserID) on delete cascade
) engine=InnoDB default charset=utf8mb4;

-- 9. Weekly report
create table WeeklyReport (
    ReportID int auto_increment primary key,
    ReportTitle varchar(100) not null,
    MarkdownContent text not null,
    StartDate date not null,
    EndDate date not null,
    UserID int not null,
    CreatedAt timestamp default current_timestamp,
    UpdatedAt timestamp default current_timestamp on update current_timestamp,
    DeletedAt timestamp,
    foreign key (UserID) references `User`(UserID) on delete cascade
) engine=InnoDB default charset=utf8mb4;

-- 10. Weekly report source logs
create table WeeklyReportLog (
    ReportID int not null,
    LogID int not null,
    CreatedAt timestamp default current_timestamp,
    primary key (ReportID, LogID),
    foreign key (ReportID) references WeeklyReport(ReportID) on delete cascade,
    foreign key (LogID) references StudyLog(LogID) on delete cascade
) engine=InnoDB default charset=utf8mb4;

-- 11. Study note
create table StudyNote (
    NoteID int auto_increment primary key,
    UserID int not null,
    CourseID int,
    ParentID int,
    Title varchar(100) not null,
    Content text,
    IsFolder tinyint(1) default 0,
    CreatedAt timestamp default current_timestamp,
    UpdatedAt timestamp default current_timestamp on update current_timestamp,
    DeletedAt timestamp,
    foreign key (UserID) references `User`(UserID) on delete cascade,
    foreign key (CourseID) references Course(CourseID) on delete set null,
    foreign key (ParentID) references StudyNote(NoteID) on delete set null
) engine=InnoDB default charset=utf8mb4;

-- 12. Note block
create table NoteBlock (
    BlockID int auto_increment primary key,
    NoteID int not null,
    BlockType enum('TEXT', 'HEADING', 'BULLET', 'CODE', 'DIVIDER', 'TODO') default 'TEXT',
    Content text,
    IsChecked tinyint(1) default 0,
    Position int default 0,
    CreatedAt timestamp default current_timestamp,
    UpdatedAt timestamp default current_timestamp on update current_timestamp,
    foreign key (NoteID) references StudyNote(NoteID) on delete cascade
) engine=InnoDB default charset=utf8mb4;

-- 13. AI chat session
create table AiChatSession (
    SessionID int auto_increment primary key,
    UserID int not null,
    Title varchar(100) default 'New chat',
    CreatedAt timestamp default current_timestamp,
    UpdatedAt timestamp default current_timestamp on update current_timestamp,
    foreign key (UserID) references `User`(UserID) on delete cascade
) engine=InnoDB default charset=utf8mb4;

-- 14. AI chat message
create table AiChatMessage (
    MessageID int auto_increment primary key,
    SessionID int not null,
    Role enum('USER', 'ASSISTANT') not null,
    Content text not null,
    CreatedAt timestamp default current_timestamp,
    foreign key (SessionID) references AiChatSession(SessionID) on delete cascade
) engine=InnoDB default charset=utf8mb4;

-- 15. AI config
create table AiConfig (
    ConfigID int auto_increment primary key,
    UserID int not null unique,
    Provider varchar(30) default 'deepseek',
    BaseUrl varchar(255) default 'https://api.deepseek.com',
    Model varchar(100) default 'deepseek-v4-flash',
    AppId varchar(100) default '',
    BlueHeartModel varchar(100) default 'Volc-DeepSeek-V3.2',
    Temperature decimal(4,2) default 0.70,
    MaxTokens int default 1200,
    TopP decimal(4,2) default 0.70,
    ThinkingMode tinyint(1) default 0,
    ThinkingEnabled tinyint(1) default 0,
    FrequencyPenalty decimal(4,2) default 0.00,
    PresencePenalty decimal(4,2) default 0.00,
    ReasoningEffort varchar(50) default '',
    IsEnabled tinyint(1) default 0,
    UpdatedAt timestamp default current_timestamp on update current_timestamp,
    foreign key (UserID) references `User`(UserID) on delete cascade
) engine=InnoDB default charset=utf8mb4;
