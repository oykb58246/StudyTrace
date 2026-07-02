-- 1. 用户
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

-- 2. 学习小组
create table StudyGroup (
    GroupID int auto_increment primary key,
    GroupName varchar(50) not null,
    InviteCode varchar(10) not null,
    CreatedAt timestamp default current_timestamp
) engine=InnoDB default charset=utf8mb4;

-- 3. 组员
create table GroupMember (
    UserID int not null,
    GroupID int not null,
    JoinDate date default (CURRENT_DATE),
    Role enum('ADMIN', 'MEMBER') default 'MEMBER',
    primary key (UserID, GroupID),
    foreign key (UserID) references `User`(UserID) on delete cascade,
    foreign key (GroupID) references StudyGroup(GroupID) on delete cascade
) engine=InnoDB default charset=utf8mb4;

-- 4. 课程
create table Course (
    CourseID int auto_increment primary key,
    CourseName varchar(50) not null,
    UserID int not null,
    CreatedAt timestamp default current_timestamp,
    UpdatedAt timestamp default current_timestamp on update current_timestamp,
    DeletedAt timestamp,
    foreign key (UserID) references `User`(UserID) on delete cascade
) engine=InnoDB default charset=utf8mb4;

-- 5. 学习任务
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

-- 6. 子任务
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

-- 7. 学习日志
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

-- 8. 知识闪卡
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

-- 9. 周报
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

-- 10. 学习笔记
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

-- 11. AI聊天会话
create table AiChatSession (
    SessionID int auto_increment primary key,
    UserID int not null,
    Title varchar(100) default 'New chat',
    CreatedAt timestamp default current_timestamp,
    UpdatedAt timestamp default current_timestamp on update current_timestamp,
    foreign key (UserID) references `User`(UserID) on delete cascade
) engine=InnoDB default charset=utf8mb4;

-- 12. AI聊天消息
create table AiChatMessage (
    MessageID int auto_increment primary key,
    SessionID int not null,
    Role enum('USER', 'ASSISTANT') not null,
    Content text not null,
    CreatedAt timestamp default current_timestamp,
    foreign key (SessionID) references AiChatSession(SessionID) on delete cascade
) engine=InnoDB default charset=utf8mb4;

-- 13. AI配置
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

-- 删除学习任务及其子任务的存储过程
drop procedure if exists spDeleteTaskWithSubtasks;
delimiter //
create procedure spDeleteTaskWithSubtasks(
    in pTaskID int
)
begin
    declare vTaskCount int default 0;

    declare exit handler for sqlexception
    begin
        rollback;
        resignal;
    end;

    start transaction;

    select count(*)
    into vTaskCount
    from StudyTask
    where TaskID = pTaskID
      and DeletedAt is null
    for update;

    if vTaskCount = 0 then
        signal sqlstate '45000'
            set message_text = 'Study task not found or already deleted';
    end if;

    update SubTask
    set DeletedAt = CURRENT_TIMESTAMP
    where TaskID = pTaskID and DeletedAt is null;

    update StudyTask
    set DeletedAt = CURRENT_TIMESTAMP
    where TaskID = pTaskID and DeletedAt is null;

    commit;
end//
delimiter ;

-- 删除课程及其关联任务、子任务、日志、闪卡、笔记的存储过程
drop procedure if exists spDeleteCourseWithRelations;
delimiter //
create procedure spDeleteCourseWithRelations(
    in pCourseID int
)
begin
    declare vCourseCount int default 0;

    declare exit handler for sqlexception
    begin
        rollback;
        resignal;
    end;

    start transaction;

    select count(*)
    into vCourseCount
    from Course
    where CourseID = pCourseID
      and DeletedAt is null
    for update;

    if vCourseCount = 0 then
        signal sqlstate '45000'
            set message_text = 'Course not found or already deleted';
    end if;

    update SubTask
    set DeletedAt = CURRENT_TIMESTAMP
    where TaskID in (
        select TaskID
        from StudyTask
        where CourseID = pCourseID
    )
      and DeletedAt is null;

    update StudyTask
    set DeletedAt = CURRENT_TIMESTAMP
    where CourseID = pCourseID
      and DeletedAt is null;

    update StudyLog
    set DeletedAt = CURRENT_TIMESTAMP
    where CourseID = pCourseID
      and DeletedAt is null;

    update Flashcard
    set DeletedAt = CURRENT_TIMESTAMP
    where CourseID = pCourseID
      and DeletedAt is null;

    update StudyNote
    set DeletedAt = CURRENT_TIMESTAMP
    where CourseID = pCourseID
      and DeletedAt is null;

    update Course
    set DeletedAt = CURRENT_TIMESTAMP
    where CourseID = pCourseID
      and DeletedAt is null;

    commit;
end//
delimiter ;

-- 触发器，当插入StudyLog时，自动更新User的TotalPoints和StreakDays
drop trigger if exists trgStudyLog;
delimiter //
create trigger trgStudyLog
after insert on StudyLog
for each row
begin
    declare vCurrentDate date;
    declare vPrevLogDate date;
    declare vSameDayLogCount int default 0;

    if NEW.Duration is not null and NEW.Duration < 0 then
        signal sqlstate '45000'
            set message_text = 'Duration must be greater than or equal to 0';
    end if;

    set vCurrentDate = coalesce(NEW.RecordDate, current_date());

    select count(*)
    into vSameDayLogCount
    from StudyLog
    where UserID = NEW.UserID
      and DeletedAt is null
      and LogID <> NEW.LogID
      and RecordDate = vCurrentDate;

    select max(RecordDate)
    into vPrevLogDate
    from StudyLog
    where UserID = NEW.UserID
      and DeletedAt is null
      and LogID <> NEW.LogID
      and RecordDate < vCurrentDate;

    update `User`
    set
        TotalPoints = TotalPoints + 10 + floor(greatest(coalesce(NEW.Duration, 0), 0) / 30),
        StreakDays = case
            when vSameDayLogCount > 0 then StreakDays
            when vPrevLogDate = date_sub(vCurrentDate, interval 1 day) then StreakDays + 1
            else 1
        end
    where UserID = NEW.UserID;
end//
delimiter ;

-- 存储过程，更新StudyTask的状态，并根据状态变化更新User的TotalPoints
drop procedure if exists spUpdateTaskStatus;
delimiter //
create procedure spUpdateTaskStatus(
    in pTaskID int,
    in pStatus varchar(20)
)
begin
    declare vUserID int;
    declare vOldStatus varchar(20);
    declare vSubtaskDoneCount int default 0;
    declare vTaskFound tinyint default 1;

    declare continue handler for not found
        set vTaskFound = 0;

    declare exit handler for sqlexception
    begin
        rollback;
        resignal;
    end;

    start transaction;

    if pStatus is null
       or pStatus not in ('NOT_STARTED', 'IN_PROGRESS', 'COMPLETED') then
        signal sqlstate '45000'
            set message_text = 'Invalid task status';
    end if;

    select UserID, Status
    into vUserID, vOldStatus
    from StudyTask
    where TaskID = pTaskID and DeletedAt is null
    for update;

    if vTaskFound = 0 then
        signal sqlstate '45000'
            set message_text = 'Task not found or already deleted';
    end if;

    update StudyTask
    set Status = pStatus
    where TaskID = pTaskID and DeletedAt is null;

    if pStatus = 'COMPLETED' and vOldStatus <> 'COMPLETED' then
        select count(*)
        into vSubtaskDoneCount
        from SubTask
        where TaskID = pTaskID
          and Status = 'COMPLETED'
          and DeletedAt is null;

        update `User`
        set TotalPoints = TotalPoints + 20 + vSubtaskDoneCount * 5
        where UserID = vUserID;
    end if;

    commit;
end//
delimiter ;

-- 视图，按学习任务页面需要的字段展示任务，并通过课程表和用户表校验关联关系
drop view if exists vTaskOverview;
create view vTaskOverview as
select
    TaskID,
    Title,
    TaskType,
    ReminderTime,
    Status,
    Note,
    Deadline,
    CourseID,
    UserID
from StudyTask
where DeletedAt is null;

-- 视图，按子任务页面需要的字段展示子任务，并通过学习任务表校验关联关系
drop view if exists vSubTaskOverview;
create view vSubTaskOverview as
select
    st.SubTaskID,
    st.Content,
    st.StartAt,
    st.Deadline,
    st.Status,
    st.Note,
    st.TaskID,
    st.CreatedAt
from SubTask st
join StudyTask t on st.TaskID = t.TaskID
where st.DeletedAt is null
  and t.DeletedAt is null;

-- 视图，展示用户负责的课程
drop view if exists vUserCourses;
create view vUserCourses as
select
    u.UserID,
    u.Username,
    c.CourseID,
    c.CourseName,
    c.CreatedAt
from `User` u
join Course c on u.UserID = c.UserID
where c.DeletedAt is null;

-- 视图，展示用户关联的课程任务
drop view if exists vUserTasks;
create view vUserTasks as
select
    u.UserID,
    u.Username,
    t.TaskID,
    t.Title,
    t.TaskType,
    t.Status,
    t.Deadline,
    t.CourseID
from `User` u
join StudyTask t on u.UserID = t.UserID
where t.DeletedAt is null;

-- 视图，展示用户学习日志
drop view if exists vUserLogs;
create view vUserLogs as
select
    u.UserID,
    u.Username,
    l.LogID,
    l.MainContent,
    l.Duration,
    l.RecordDate,
    l.CourseID
from `User` u
join StudyLog l on u.UserID = l.UserID
where l.DeletedAt is null;

-- 视图，展示用户加入的小组
drop view if exists vUserGroups;
create view vUserGroups as
select
    u.UserID,
    u.Username,
    g.GroupID,
    g.GroupName,
    g.InviteCode,
    gm.Role,
    gm.JoinDate
from `User` u
join GroupMember gm on u.UserID = gm.UserID
join StudyGroup g on gm.GroupID = g.GroupID;
