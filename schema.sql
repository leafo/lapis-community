--
-- PostgreSQL database dump
--

-- Dumped from database version 14.6
-- Dumped by pg_dump version 14.6

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: community_activity_logs; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.community_activity_logs (
    id integer NOT NULL,
    user_id integer NOT NULL,
    object_type integer DEFAULT 0 NOT NULL,
    object_id integer NOT NULL,
    action integer DEFAULT 0 NOT NULL,
    data jsonb,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    ip inet
);


ALTER TABLE public.community_activity_logs OWNER TO postgres;

--
-- Name: community_activity_logs_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.community_activity_logs_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.community_activity_logs_id_seq OWNER TO postgres;

--
-- Name: community_activity_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.community_activity_logs_id_seq OWNED BY public.community_activity_logs.id;


--
-- Name: community_bans; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.community_bans (
    object_type integer DEFAULT 0 NOT NULL,
    object_id integer NOT NULL,
    banned_user_id integer NOT NULL,
    reason text,
    banning_user_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


ALTER TABLE public.community_bans OWNER TO postgres;

--
-- Name: community_blocks; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.community_blocks (
    blocking_user_id integer NOT NULL,
    blocked_user_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


ALTER TABLE public.community_blocks OWNER TO postgres;

--
-- Name: community_bookmarks; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.community_bookmarks (
    user_id integer NOT NULL,
    object_type integer DEFAULT 0 NOT NULL,
    object_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


ALTER TABLE public.community_bookmarks OWNER TO postgres;

--
-- Name: community_categories; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.community_categories (
    id integer NOT NULL,
    title character varying(255),
    slug character varying(255),
    user_id integer,
    parent_category_id integer,
    last_topic_id integer,
    topics_count integer DEFAULT 0 NOT NULL,
    deleted_topics_count integer DEFAULT 0 NOT NULL,
    views_count integer DEFAULT 0 NOT NULL,
    short_description text,
    description text,
    rules text,
    membership_type integer,
    voting_type integer,
    archived boolean DEFAULT false NOT NULL,
    hidden boolean DEFAULT false NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    category_groups_count integer DEFAULT 0 NOT NULL,
    approval_type smallint,
    "position" integer DEFAULT 0 NOT NULL,
    directory boolean DEFAULT false NOT NULL,
    topic_posting_type smallint,
    category_order_type smallint DEFAULT 1 NOT NULL,
    data jsonb
);


ALTER TABLE public.community_categories OWNER TO postgres;

--
-- Name: community_categories_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.community_categories_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.community_categories_id_seq OWNER TO postgres;

--
-- Name: community_categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.community_categories_id_seq OWNED BY public.community_categories.id;


--
-- Name: community_category_group_categories; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.community_category_group_categories (
    category_group_id integer NOT NULL,
    category_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


ALTER TABLE public.community_category_group_categories OWNER TO postgres;

--
-- Name: community_category_groups; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.community_category_groups (
    id integer NOT NULL,
    title character varying(255),
    user_id integer,
    categories_count integer DEFAULT 0 NOT NULL,
    description text,
    rules text,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


ALTER TABLE public.community_category_groups OWNER TO postgres;

--
-- Name: community_category_groups_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.community_category_groups_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.community_category_groups_id_seq OWNER TO postgres;

--
-- Name: community_category_groups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.community_category_groups_id_seq OWNED BY public.community_category_groups.id;


--
-- Name: community_category_members; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.community_category_members (
    user_id integer NOT NULL,
    category_id integer NOT NULL,
    accepted boolean DEFAULT false NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


ALTER TABLE public.community_category_members OWNER TO postgres;

--
-- Name: community_category_post_logs; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.community_category_post_logs (
    category_id integer NOT NULL,
    post_id integer NOT NULL
);


ALTER TABLE public.community_category_post_logs OWNER TO postgres;

--
-- Name: community_category_tags; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.community_category_tags (
    id integer NOT NULL,
    category_id integer NOT NULL,
    slug character varying(255) NOT NULL,
    label text,
    color character varying(255),
    image_url character varying(255),
    tag_order integer DEFAULT 0 NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    description text
);


ALTER TABLE public.community_category_tags OWNER TO postgres;

--
-- Name: community_category_tags_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.community_category_tags_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.community_category_tags_id_seq OWNER TO postgres;

--
-- Name: community_category_tags_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.community_category_tags_id_seq OWNED BY public.community_category_tags.id;


--
-- Name: community_moderation_log_objects; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.community_moderation_log_objects (
    moderation_log_id integer NOT NULL,
    object_type integer DEFAULT 0 NOT NULL,
    object_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


ALTER TABLE public.community_moderation_log_objects OWNER TO postgres;

--
-- Name: community_moderation_logs; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.community_moderation_logs (
    id integer NOT NULL,
    category_id integer,
    object_type integer DEFAULT 0 NOT NULL,
    object_id integer NOT NULL,
    user_id integer NOT NULL,
    action character varying(255) NOT NULL,
    reason text,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    data jsonb
);


ALTER TABLE public.community_moderation_logs OWNER TO postgres;

--
-- Name: community_moderation_logs_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.community_moderation_logs_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.community_moderation_logs_id_seq OWNER TO postgres;

--
-- Name: community_moderation_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.community_moderation_logs_id_seq OWNED BY public.community_moderation_logs.id;


--
-- Name: community_moderators; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.community_moderators (
    user_id integer NOT NULL,
    object_type integer NOT NULL,
    object_id integer NOT NULL,
    admin boolean DEFAULT false NOT NULL,
    accepted boolean DEFAULT false NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


ALTER TABLE public.community_moderators OWNER TO postgres;

--
-- Name: community_pending_posts; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.community_pending_posts (
    id integer NOT NULL,
    category_id integer,
    topic_id integer,
    user_id integer NOT NULL,
    parent_post_id integer,
    status smallint NOT NULL,
    body text NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    title character varying(255),
    body_format smallint DEFAULT 1 NOT NULL,
    data jsonb,
    reason smallint DEFAULT 1 NOT NULL
);


ALTER TABLE public.community_pending_posts OWNER TO postgres;

--
-- Name: community_pending_posts_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.community_pending_posts_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.community_pending_posts_id_seq OWNER TO postgres;

--
-- Name: community_pending_posts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.community_pending_posts_id_seq OWNED BY public.community_pending_posts.id;


--
-- Name: community_post_edits; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.community_post_edits (
    id integer NOT NULL,
    post_id integer NOT NULL,
    user_id integer NOT NULL,
    body_before text NOT NULL,
    reason text,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    body_format smallint DEFAULT 1 NOT NULL
);


ALTER TABLE public.community_post_edits OWNER TO postgres;

--
-- Name: community_post_edits_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.community_post_edits_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.community_post_edits_id_seq OWNER TO postgres;

--
-- Name: community_post_edits_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.community_post_edits_id_seq OWNED BY public.community_post_edits.id;


--
-- Name: community_post_reports; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.community_post_reports (
    id integer NOT NULL,
    category_id integer,
    post_id integer NOT NULL,
    user_id integer NOT NULL,
    category_report_number integer DEFAULT 0 NOT NULL,
    moderating_user_id integer,
    status integer DEFAULT 0 NOT NULL,
    reason integer DEFAULT 0 NOT NULL,
    body text,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    moderated_at timestamp without time zone,
    post_user_id integer,
    post_parent_post_id integer,
    post_body text,
    post_body_format smallint,
    post_topic_id integer
);


ALTER TABLE public.community_post_reports OWNER TO postgres;

--
-- Name: community_post_reports_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.community_post_reports_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.community_post_reports_id_seq OWNER TO postgres;

--
-- Name: community_post_reports_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.community_post_reports_id_seq OWNED BY public.community_post_reports.id;


--
-- Name: community_posts; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.community_posts (
    id integer NOT NULL,
    topic_id integer NOT NULL,
    user_id integer NOT NULL,
    parent_post_id integer,
    post_number integer DEFAULT 0 NOT NULL,
    depth integer DEFAULT 0 NOT NULL,
    deleted boolean DEFAULT false NOT NULL,
    body text NOT NULL,
    down_votes_count integer DEFAULT 0 NOT NULL,
    up_votes_count integer DEFAULT 0 NOT NULL,
    edits_count integer DEFAULT 0 NOT NULL,
    last_edited_at timestamp without time zone,
    deleted_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    status smallint DEFAULT 1 NOT NULL,
    moderation_log_id integer,
    body_format smallint DEFAULT 1 NOT NULL,
    pin_position integer,
    popularity_score integer DEFAULT 0
);


ALTER TABLE public.community_posts OWNER TO postgres;

--
-- Name: community_posts_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.community_posts_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.community_posts_id_seq OWNER TO postgres;

--
-- Name: community_posts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.community_posts_id_seq OWNED BY public.community_posts.id;


--
-- Name: community_posts_search; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.community_posts_search (
    post_id integer NOT NULL,
    topic_id integer NOT NULL,
    category_id integer,
    posted_at timestamp without time zone NOT NULL,
    words tsvector
);


ALTER TABLE public.community_posts_search OWNER TO postgres;

--
-- Name: community_subscriptions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.community_subscriptions (
    object_type smallint NOT NULL,
    object_id integer NOT NULL,
    user_id integer NOT NULL,
    subscribed boolean DEFAULT true NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


ALTER TABLE public.community_subscriptions OWNER TO postgres;

--
-- Name: community_topic_participants; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.community_topic_participants (
    topic_id integer NOT NULL,
    user_id integer NOT NULL,
    posts_count integer DEFAULT 0 NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


ALTER TABLE public.community_topic_participants OWNER TO postgres;

--
-- Name: community_topics; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.community_topics (
    id integer NOT NULL,
    category_id integer,
    user_id integer,
    title character varying(255),
    slug character varying(255),
    last_post_id integer,
    locked boolean DEFAULT false NOT NULL,
    sticky boolean DEFAULT false NOT NULL,
    permanent boolean DEFAULT false NOT NULL,
    deleted boolean DEFAULT false NOT NULL,
    posts_count integer DEFAULT 0 NOT NULL,
    deleted_posts_count integer DEFAULT 0 NOT NULL,
    root_posts_count integer DEFAULT 0 NOT NULL,
    views_count integer DEFAULT 0 NOT NULL,
    category_order integer DEFAULT 0 NOT NULL,
    deleted_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    status smallint DEFAULT 1 NOT NULL,
    tags character varying(255)[],
    rank_adjustment integer DEFAULT 0 NOT NULL,
    protected boolean DEFAULT false NOT NULL,
    data jsonb
);


ALTER TABLE public.community_topics OWNER TO postgres;

--
-- Name: community_topics_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.community_topics_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.community_topics_id_seq OWNER TO postgres;

--
-- Name: community_topics_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.community_topics_id_seq OWNED BY public.community_topics.id;


--
-- Name: community_user_category_last_seens; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.community_user_category_last_seens (
    user_id integer NOT NULL,
    category_id integer NOT NULL,
    category_order integer DEFAULT 0 NOT NULL,
    topic_id integer NOT NULL
);


ALTER TABLE public.community_user_category_last_seens OWNER TO postgres;

--
-- Name: community_user_topic_last_seens; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.community_user_topic_last_seens (
    user_id integer NOT NULL,
    topic_id integer NOT NULL,
    post_id integer NOT NULL
);


ALTER TABLE public.community_user_topic_last_seens OWNER TO postgres;

--
-- Name: community_users; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.community_users (
    user_id integer NOT NULL,
    posts_count integer DEFAULT 0 NOT NULL,
    topics_count integer DEFAULT 0 NOT NULL,
    votes_count integer DEFAULT 0 NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    flair character varying(255),
    recent_posts_count integer DEFAULT 0 NOT NULL,
    last_post_at timestamp without time zone,
    posting_permission smallint DEFAULT 1 NOT NULL,
    received_up_votes_count integer DEFAULT 0 NOT NULL,
    received_down_votes_count integer DEFAULT 0 NOT NULL,
    received_votes_adjustment integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.community_users OWNER TO postgres;

--
-- Name: community_votes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.community_votes (
    user_id integer NOT NULL,
    object_type integer NOT NULL,
    object_id integer NOT NULL,
    positive boolean DEFAULT false NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    ip inet,
    counted boolean DEFAULT true NOT NULL,
    score integer
);


ALTER TABLE public.community_votes OWNER TO postgres;

--
-- Name: lapis_migrations; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.lapis_migrations (
    name character varying(255) NOT NULL
);


ALTER TABLE public.lapis_migrations OWNER TO postgres;

--
-- Name: users; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.users (
    id integer NOT NULL,
    username character varying(255) NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


ALTER TABLE public.users OWNER TO postgres;

--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.users_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.users_id_seq OWNER TO postgres;

--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: community_activity_logs id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.community_activity_logs ALTER COLUMN id SET DEFAULT nextval('public.community_activity_logs_id_seq'::regclass);


--
-- Name: community_categories id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.community_categories ALTER COLUMN id SET DEFAULT nextval('public.community_categories_id_seq'::regclass);


--
-- Name: community_category_groups id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.community_category_groups ALTER COLUMN id SET DEFAULT nextval('public.community_category_groups_id_seq'::regclass);


--
-- Name: community_category_tags id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.community_category_tags ALTER COLUMN id SET DEFAULT nextval('public.community_category_tags_id_seq'::regclass);


--
-- Name: community_moderation_logs id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.community_moderation_logs ALTER COLUMN id SET DEFAULT nextval('public.community_moderation_logs_id_seq'::regclass);


--
-- Name: community_pending_posts id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.community_pending_posts ALTER COLUMN id SET DEFAULT nextval('public.community_pending_posts_id_seq'::regclass);


--
-- Name: community_post_edits id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.community_post_edits ALTER COLUMN id SET DEFAULT nextval('public.community_post_edits_id_seq'::regclass);


--
-- Name: community_post_reports id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.community_post_reports ALTER COLUMN id SET DEFAULT nextval('public.community_post_reports_id_seq'::regclass);


--
-- Name: community_posts id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.community_posts ALTER COLUMN id SET DEFAULT nextval('public.community_posts_id_seq'::regclass);


--
-- Name: community_topics id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.community_topics ALTER COLUMN id SET DEFAULT nextval('public.community_topics_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: community_activity_logs community_activity_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.community_activity_logs
    ADD CONSTRAINT community_activity_logs_pkey PRIMARY KEY (id);


--
-- Name: community_bans community_bans_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.community_bans
    ADD CONSTRAINT community_bans_pkey PRIMARY KEY (object_type, object_id, banned_user_id);


--
-- Name: community_blocks community_blocks_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.community_blocks
    ADD CONSTRAINT community_blocks_pkey PRIMARY KEY (blocking_user_id, blocked_user_id);


--
-- Name: community_bookmarks community_bookmarks_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.community_bookmarks
    ADD CONSTRAINT community_bookmarks_pkey PRIMARY KEY (user_id, object_type, object_id);


--
-- Name: community_categories community_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.community_categories
    ADD CONSTRAINT community_categories_pkey PRIMARY KEY (id);


--
-- Name: community_category_group_categories community_category_group_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.community_category_group_categories
    ADD CONSTRAINT community_category_group_categories_pkey PRIMARY KEY (category_group_id, category_id);


--
-- Name: community_category_groups community_category_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.community_category_groups
    ADD CONSTRAINT community_category_groups_pkey PRIMARY KEY (id);


--
-- Name: community_category_members community_category_members_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.community_category_members
    ADD CONSTRAINT community_category_members_pkey PRIMARY KEY (user_id, category_id);


--
-- Name: community_category_post_logs community_category_post_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.community_category_post_logs
    ADD CONSTRAINT community_category_post_logs_pkey PRIMARY KEY (category_id, post_id);


--
-- Name: community_category_tags community_category_tags_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.community_category_tags
    ADD CONSTRAINT community_category_tags_pkey PRIMARY KEY (id);


--
-- Name: community_moderation_log_objects community_moderation_log_objects_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.community_moderation_log_objects
    ADD CONSTRAINT community_moderation_log_objects_pkey PRIMARY KEY (moderation_log_id, object_type, object_id);


--
-- Name: community_moderation_logs community_moderation_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.community_moderation_logs
    ADD CONSTRAINT community_moderation_logs_pkey PRIMARY KEY (id);


--
-- Name: community_moderators community_moderators_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.community_moderators
    ADD CONSTRAINT community_moderators_pkey PRIMARY KEY (user_id, object_type, object_id);


--
-- Name: community_pending_posts community_pending_posts_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.community_pending_posts
    ADD CONSTRAINT community_pending_posts_pkey PRIMARY KEY (id);


--
-- Name: community_post_edits community_post_edits_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.community_post_edits
    ADD CONSTRAINT community_post_edits_pkey PRIMARY KEY (id);


--
-- Name: community_post_reports community_post_reports_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.community_post_reports
    ADD CONSTRAINT community_post_reports_pkey PRIMARY KEY (id);


--
-- Name: community_posts community_posts_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.community_posts
    ADD CONSTRAINT community_posts_pkey PRIMARY KEY (id);


--
-- Name: community_posts_search community_posts_search_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.community_posts_search
    ADD CONSTRAINT community_posts_search_pkey PRIMARY KEY (post_id);


--
-- Name: community_subscriptions community_subscriptions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.community_subscriptions
    ADD CONSTRAINT community_subscriptions_pkey PRIMARY KEY (object_type, object_id, user_id);


--
-- Name: community_topic_participants community_topic_participants_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.community_topic_participants
    ADD CONSTRAINT community_topic_participants_pkey PRIMARY KEY (topic_id, user_id);


--
-- Name: community_topics community_topics_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.community_topics
    ADD CONSTRAINT community_topics_pkey PRIMARY KEY (id);


--
-- Name: community_user_category_last_seens community_user_category_last_seens_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.community_user_category_last_seens
    ADD CONSTRAINT community_user_category_last_seens_pkey PRIMARY KEY (user_id, category_id);


--
-- Name: community_user_topic_last_seens community_user_topic_last_seens_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.community_user_topic_last_seens
    ADD CONSTRAINT community_user_topic_last_seens_pkey PRIMARY KEY (user_id, topic_id);


--
-- Name: community_users community_users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.community_users
    ADD CONSTRAINT community_users_pkey PRIMARY KEY (user_id);


--
-- Name: community_votes community_votes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.community_votes
    ADD CONSTRAINT community_votes_pkey PRIMARY KEY (user_id, object_type, object_id);


--
-- Name: lapis_migrations lapis_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.lapis_migrations
    ADD CONSTRAINT lapis_migrations_pkey PRIMARY KEY (name);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: community_activity_logs_object_type_object_id_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX community_activity_logs_object_type_object_id_idx ON public.community_activity_logs USING btree (object_type, object_id);


--
-- Name: community_activity_logs_user_id_id_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX community_activity_logs_user_id_id_idx ON public.community_activity_logs USING btree (user_id, id);


--
-- Name: community_bans_banned_user_id_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX community_bans_banned_user_id_idx ON public.community_bans USING btree (banned_user_id);


--
-- Name: community_bans_banning_user_id_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX community_bans_banning_user_id_idx ON public.community_bans USING btree (banning_user_id);


--
-- Name: community_bans_object_type_object_id_created_at_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX community_bans_object_type_object_id_created_at_idx ON public.community_bans USING btree (object_type, object_id, created_at);


--
-- Name: community_bookmarks_user_id_created_at_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX community_bookmarks_user_id_created_at_idx ON public.community_bookmarks USING btree (user_id, created_at);


--
-- Name: community_categories_parent_category_id_position_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX community_categories_parent_category_id_position_idx ON public.community_categories USING btree (parent_category_id, "position") WHERE (parent_category_id IS NOT NULL);


--
-- Name: community_category_group_categories_category_id_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX community_category_group_categories_category_id_idx ON public.community_category_group_categories USING btree (category_id);


--
-- Name: community_category_members_category_id_user_id_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX community_category_members_category_id_user_id_idx ON public.community_category_members USING btree (category_id, user_id) WHERE accepted;


--
-- Name: community_category_post_logs_post_id_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX community_category_post_logs_post_id_idx ON public.community_category_post_logs USING btree (post_id);


--
-- Name: community_category_tags_category_id_slug_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX community_category_tags_category_id_slug_idx ON public.community_category_tags USING btree (category_id, slug);


--
-- Name: community_moderation_logs_category_id_id_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX community_moderation_logs_category_id_id_idx ON public.community_moderation_logs USING btree (category_id, id) WHERE (category_id IS NOT NULL);


--
-- Name: community_moderation_logs_object_type_object_id_action_id_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX community_moderation_logs_object_type_object_id_action_id_idx ON public.community_moderation_logs USING btree (object_type, object_id, action, id);


--
-- Name: community_moderation_logs_user_id_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX community_moderation_logs_user_id_idx ON public.community_moderation_logs USING btree (user_id);


--
-- Name: community_moderators_object_type_object_id_created_at_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX community_moderators_object_type_object_id_created_at_idx ON public.community_moderators USING btree (object_type, object_id, created_at);


--
-- Name: community_pending_posts_category_id_status_id_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX community_pending_posts_category_id_status_id_idx ON public.community_pending_posts USING btree (category_id, status, id) WHERE (category_id IS NOT NULL);


--
-- Name: community_pending_posts_topic_id_status_id_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX community_pending_posts_topic_id_status_id_idx ON public.community_pending_posts USING btree (topic_id, status, id) WHERE (topic_id IS NOT NULL);


--
-- Name: community_post_edits_post_id_id_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX community_post_edits_post_id_id_idx ON public.community_post_edits USING btree (post_id, id);


--
-- Name: community_post_reports_category_id_id_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX community_post_reports_category_id_id_idx ON public.community_post_reports USING btree (category_id, id) WHERE (category_id IS NOT NULL);


--
-- Name: community_post_reports_post_id_id_status_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX community_post_reports_post_id_id_status_idx ON public.community_post_reports USING btree (post_id, id, status);


--
-- Name: community_post_reports_post_user_id_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX community_post_reports_post_user_id_idx ON public.community_post_reports USING btree (post_user_id) WHERE (post_user_id IS NOT NULL);


--
-- Name: community_posts_moderation_log_id_not_null_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX community_posts_moderation_log_id_not_null_key ON public.community_posts USING btree (moderation_log_id) WHERE (moderation_log_id IS NOT NULL);


--
-- Name: community_posts_parent_post_id_popularity_score_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX community_posts_parent_post_id_popularity_score_idx ON public.community_posts USING btree (parent_post_id, popularity_score) WHERE ((popularity_score IS NOT NULL) AND (parent_post_id IS NOT NULL));


--
-- Name: community_posts_parent_post_id_post_number_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX community_posts_parent_post_id_post_number_idx ON public.community_posts USING btree (parent_post_id, post_number);


--
-- Name: community_posts_parent_post_id_status_post_number_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX community_posts_parent_post_id_status_post_number_idx ON public.community_posts USING btree (parent_post_id, status, post_number);


--
-- Name: community_posts_search_post_id_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX community_posts_search_post_id_idx ON public.community_posts_search USING btree (post_id);


--
-- Name: community_posts_search_words_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX community_posts_search_words_idx ON public.community_posts_search USING gin (words);


--
-- Name: community_posts_topic_id_id_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX community_posts_topic_id_id_idx ON public.community_posts USING btree (topic_id, id) WHERE (NOT deleted);


--
-- Name: community_posts_topic_id_parent_post_id_depth_post_number_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX community_posts_topic_id_parent_post_id_depth_post_number_idx ON public.community_posts USING btree (topic_id, parent_post_id, depth, post_number);


--
-- Name: community_posts_topic_id_parent_post_id_depth_status_post_numbe; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX community_posts_topic_id_parent_post_id_depth_status_post_numbe ON public.community_posts USING btree (topic_id, parent_post_id, depth, status, post_number);


--
-- Name: community_posts_topic_id_popularity_score_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX community_posts_topic_id_popularity_score_idx ON public.community_posts USING btree (topic_id, popularity_score) WHERE (popularity_score IS NOT NULL);


--
-- Name: community_posts_user_id_id_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX community_posts_user_id_id_idx ON public.community_posts USING btree (user_id, id);


--
-- Name: community_subscriptions_user_id_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX community_subscriptions_user_id_idx ON public.community_subscriptions USING btree (user_id);


--
-- Name: community_topics_category_id_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX community_topics_category_id_idx ON public.community_topics USING btree (category_id) WHERE (category_id IS NOT NULL);


--
-- Name: community_topics_category_id_sticky_status_category_order_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX community_topics_category_id_sticky_status_category_order_idx ON public.community_topics USING btree (category_id, sticky, status, category_order) WHERE ((NOT deleted) AND (category_id IS NOT NULL));


--
-- Name: community_topics_user_id_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX community_topics_user_id_idx ON public.community_topics USING btree (user_id) WHERE (user_id IS NOT NULL);


--
-- Name: community_user_topic_last_seens_topic_id_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX community_user_topic_last_seens_topic_id_idx ON public.community_user_topic_last_seens USING btree (topic_id);


--
-- Name: community_votes_object_type_object_id_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX community_votes_object_type_object_id_idx ON public.community_votes USING btree (object_type, object_id);


--
-- Name: users_lower_username_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX users_lower_username_idx ON public.users USING btree (lower((username)::text));


--
-- PostgreSQL database dump complete
--

--
-- PostgreSQL database dump
--

-- Dumped from database version 14.6
-- Dumped by pg_dump version 14.6

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Data for Name: lapis_migrations; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.lapis_migrations (name) FROM stdin;
community_1
community_2
community_3
community_4
community_5
community_6
community_7
community_8
community_9
community_10
community_11
community_12
community_13
community_14
community_15
community_16
community_17
community_18
community_19
community_20
community_21
community_22
community_23
community_24
community_25
community_26
community_27
community_28
community_29
community_30
community_31
community_32
community_33
community_34
community_35
community_36
community_37
community_38
community_39
community_40
community_41
community_42
community_43
\.


--
-- PostgreSQL database dump complete
--

