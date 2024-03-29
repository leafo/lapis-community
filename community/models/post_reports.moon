
db = require "lapis.db"
import enum from require "lapis.db.model"
import Model from require "community.model"

-- Generated schema dump: (do not edit)
--
-- CREATE TABLE community_post_reports (
--   id integer NOT NULL,
--   category_id integer,
--   post_id integer NOT NULL,
--   user_id integer NOT NULL,
--   category_report_number integer DEFAULT 0 NOT NULL,
--   moderating_user_id integer,
--   status integer DEFAULT 0 NOT NULL,
--   reason integer DEFAULT 0 NOT NULL,
--   body text,
--   created_at timestamp without time zone NOT NULL,
--   updated_at timestamp without time zone NOT NULL,
--   moderated_at timestamp without time zone,
--   post_user_id integer,
--   post_parent_post_id integer,
--   post_body text,
--   post_body_format smallint,
--   post_topic_id integer
-- );
-- ALTER TABLE ONLY community_post_reports
--   ADD CONSTRAINT community_post_reports_pkey PRIMARY KEY (id);
-- CREATE INDEX community_post_reports_category_id_id_idx ON community_post_reports USING btree (category_id, id) WHERE (category_id IS NOT NULL);
-- CREATE INDEX community_post_reports_post_id_id_status_idx ON community_post_reports USING btree (post_id, id, status);
-- CREATE INDEX community_post_reports_post_user_id_idx ON community_post_reports USING btree (post_user_id) WHERE (post_user_id IS NOT NULL);
--
class PostReports extends Model
  @timestamp: true

  @statuses: enum {
    pending: 1
    resolved: 2
    ignored: 3
  }

  @reasons: enum {
    other: 1
    off_topic: 2
    spam: 3
    offensive: 4
  }

  @relations: {
    {"category", belongs_to: "Categories"}
    {"post", belongs_to: "Posts"}
    {"user", belongs_to: "Users"}
    {"moderating_user", belongs_to: "Users"}
    {"post_user", belongs_to: "Users"}
    {"post_topic", belongs_to: "Topics"}
  }

  @create: (opts={}) =>
    opts.status or= "pending"
    opts.status = @statuses\for_db opts.status

    opts.reason = @reasons\for_db opts.reason

    tname = @table_name!

    if opts.category_id
      opts.category_report_number = db.raw db.interpolate_query "
        coalesce(
          (select category_report_number
            from #{db.escape_identifier tname} where category_id = ? order by id desc limit 1
          ), 0) + 1
      ", opts.category_id

    assert opts.post_id, "missing post_id"
    assert opts.user_id, "missing user_id"

    super opts

  is_resolved: => @status == @@statuses.resolved
  is_pending: => @status == @@statuses.pending
  is_ignored: => @status == @@statuses.ignored

  delete: (...) =>
    import ModerationLogs from require "community.models"

    db.delete ModerationLogs\table_name!, {
      object_type: assert ModerationLogs.object_types.post_report
      object_id: assert @id
    }

    super ...

