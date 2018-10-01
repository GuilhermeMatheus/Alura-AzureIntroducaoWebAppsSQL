-- Criando usuário
CREATE USER [casaDoCodigoWebApp]
WITH PASSWORD = 'SenhaAplicacao!'
   , DEFAULT_SCHEMA = dbo; 
GO 

ALTER ROLE db_datareader ADD MEMBER [casaDoCodigoWebApp]; 
ALTER ROLE db_datawriter ADD MEMBER [casaDoCodigoWebApp]; 
GO 


-- Criação das tabelas
IF OBJECT_ID(N'[__EFMigrationsHistory]') IS NULL
BEGIN
    CREATE TABLE [__EFMigrationsHistory] (
        [MigrationId] nvarchar(150) NOT NULL,
        [ProductVersion] nvarchar(32) NOT NULL,
        CONSTRAINT [PK___EFMigrationsHistory] PRIMARY KEY ([MigrationId])
    );
END;

GO

CREATE TABLE [Authors] (
    [Id] int NOT NULL IDENTITY,
    [Name] nvarchar(max) NOT NULL,
    CONSTRAINT [PK_Authors] PRIMARY KEY ([Id])
);

GO

CREATE TABLE [Categories] (
    [Id] int NOT NULL IDENTITY,
    [Name] nvarchar(max) NOT NULL,
    [ParentId] int NULL,
    CONSTRAINT [PK_Categories] PRIMARY KEY ([Id]),
    CONSTRAINT [FK_Categories_Categories_ParentId] FOREIGN KEY ([ParentId]) REFERENCES [Categories] ([Id]) ON DELETE NO ACTION
);

GO

CREATE TABLE [Books] (
    [Id] int NOT NULL IDENTITY,
    [Title] nvarchar(max) NOT NULL,
    [SubTitle] nvarchar(max) NOT NULL,
    [Summary] nvarchar(max) NOT NULL,
    [DisplayName] nvarchar(max) NOT NULL,
    [CoverUri] nvarchar(max) NULL,
    [Price] decimal(5,2) NOT NULL,
    [UpdateDate] datetime2 NOT NULL,
    [PublishDate] datetime2 NOT NULL,
    [CategoryId] int NULL,
    CONSTRAINT [PK_Books] PRIMARY KEY ([Id]),
    CONSTRAINT [FK_Books_Categories_CategoryId] FOREIGN KEY ([CategoryId]) REFERENCES [Categories] ([Id]) ON DELETE NO ACTION
);

GO

CREATE TABLE [BookAuthorJoin] (
    [AuthorId] int NOT NULL,
    [BookId] int NOT NULL,
    CONSTRAINT [PK_BookAuthorJoin] PRIMARY KEY ([BookId], [AuthorId]),
    CONSTRAINT [FK_BookAuthorJoin_Authors_AuthorId] FOREIGN KEY ([AuthorId]) REFERENCES [Authors] ([Id]) ON DELETE CASCADE,
    CONSTRAINT [FK_BookAuthorJoin_Books_BookId] FOREIGN KEY ([BookId]) REFERENCES [Books] ([Id]) ON DELETE CASCADE
);

GO

CREATE INDEX [IX_BookAuthorJoin_AuthorId] ON [BookAuthorJoin] ([AuthorId]);

GO

CREATE INDEX [IX_Books_CategoryId] ON [Books] ([CategoryId]);

GO

CREATE INDEX [IX_Categories_ParentId] ON [Categories] ([ParentId]);

GO

INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
VALUES (N'20180830034650_InitialMigration', N'2.1.2-rtm-30932');

GO

