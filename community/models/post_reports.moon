
import enum from require "lapis.db.model"
import Model from require "community.model"

-- Generated schema dump: (do not edit)
--
-- CREATE TABLE community_post_reports (
--   id integer NOT NULL,
--   category_id integer,
--   post_id integer NOT NULL,
--   user_id integer NOT NULL,
--   moderating_user_id integer,
--   status integer DEFAULT 0 NOT NULL,
--   reason integer DEFAULT 0 NOT NULL,
--   body text,
--   created_at timestamp without time zone NOT NULL,
--   updated_at timestamp without time zone NOT NULL
-- );
-- ALTER TABLE ONLY community_post_reports
--   ADD CONSTRAINT community_post_reports_pkey PRIMARY KEY (id);
-- CREATE INDEX community_post_reports_category_id_id_idx ON community_post_reports USING btree (category_id, id) WHERE (category_id IS NOT NULL);
-- CREATE INDEX community_post_reports_post_id_id_idx ON community_post_reports USING btree (post_id, id);
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
  }

  @create: (opts={}) =>
    opts.status or= "pending"
    opts.status = @statuses\for_db opts.status

    opts.reason = @reasons\for_db opts.reason

    assert opts.post_id, "missing post_id"
    assert opts.user_id, "missing user_id"

    Model.create @, opts

