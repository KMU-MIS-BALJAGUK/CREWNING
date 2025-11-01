


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


CREATE SCHEMA IF NOT EXISTS "public";


ALTER SCHEMA "public" OWNER TO "pg_database_owner";


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE TYPE "public"."register_status" AS ENUM (
    'PENDING',
    'APPROVED',
    'REJECTED'
);


ALTER TYPE "public"."register_status" OWNER TO "postgres";


CREATE TYPE "public"."user_gender" AS ENUM (
    'FEMALE',
    'MALE'
);


ALTER TYPE "public"."user_gender" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_new_user"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  insert into public.user (auth_user_id, email, name, created_at)
  values (new.id, new.email, coalesce(new.raw_user_meta_data->>'name', ''), now());
  return new;
exception when unique_violation then
  return new;
end;
$$;


ALTER FUNCTION "public"."handle_new_user"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_crew_weekly_score"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    -- --- 상수 정의 (이 값을 조절하여 밸런싱) ---
    V_MIN_PACE numeric := 3.0;     -- (방어1) 인정하는 최소 페이스 (예: 3:00 min/km)
    V_MAX_SCORE_PER_RUN real := 500; -- (방어2) 1회 획득 최대 점수 (예: 500점)
    V_MIN_DISTANCE real := 1.0;    -- 점수로 인정하는 최소 거리 (예: 1km)
    V_SCALING_FACTOR real := 100;  -- 점수 계산 상수
    -- ---------------------------------------

    v_crew_id INT;
    v_week_id TEXT;
    v_score_to_add REAL;
    v_distance REAL;
    v_pace NUMERIC;
BEGIN
    -- 1. 유저의 크루 ID 가져오기
    SELECT crew_id INTO v_crew_id
    FROM public.user
    WHERE user_id = NEW.user_id;

    -- 2. 크루가 없으면 종료
    IF v_crew_id IS NULL THEN
        RETURN NEW;
    END IF;

    -- 3. 주차(Week ID) 계산
    v_week_id := to_char(NEW.end_time, 'YYYY-IW');

    -- 4. 유효한 값 가져오기
    v_distance := COALESCE(NEW.distance, 0);
    v_pace := COALESCE(NEW.pace, 0);

    -- 5. [수정됨] 점수 계산 및 예외 처리
    
    -- (방어3) 최소 인정 거리(V_MIN_DISTANCE) 미만이면 0점 처리
    IF v_distance < V_MIN_DISTANCE THEN
        v_score_to_add := 0;
    ELSE
        -- (방어1) 페이스가 최소 페이스(V_MIN_PACE)보다 낮으면 (너무 빠르면)
        -- 페이스 값을 V_MIN_PACE로 고정합니다. (점수 폭등 방지)
        IF v_pace < V_MIN_PACE THEN
            v_pace := V_MIN_PACE;
        END IF;

        -- 점수 계산
        v_score_to_add := (v_distance * V_SCALING_FACTOR) / v_pace;

        -- (방어2) 계산된 점수가 1회 최대 점수(V_MAX_SCORE_PER_RUN)를 초과하면
        -- 점수를 V_MAX_SCORE_PER_RUN으로 고정합니다. (울트라마라톤 방어)
        IF v_score_to_add > V_MAX_SCORE_PER_RUN THEN
            v_score_to_add := V_MAX_SCORE_PER_RUN;
        END IF;
    END IF;

    -- 6. 점수가 0보다 클 때만 'crew_weekly_scores' 테이블에 UPSERT
    IF v_score_to_add > 0 THEN
        INSERT INTO public.crew_weekly_scores (crew_id, week_id, score)
        VALUES (v_crew_id, v_week_id, v_score_to_add)
        ON CONFLICT (crew_id, week_id)
        DO UPDATE SET
            score = public.crew_weekly_scores.score + v_score_to_add;
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_crew_weekly_score"() OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."area" (
    "area_id" integer NOT NULL,
    "name" character varying(30)
);


ALTER TABLE "public"."area" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."crew" (
    "crew_id" integer NOT NULL,
    "crew_name" character varying(30) NOT NULL,
    "leader_name" character varying(30),
    "max_member" integer,
    "area_id" integer,
    "weekly_score" integer DEFAULT 0,
    "total_score" integer DEFAULT 0
);


ALTER TABLE "public"."crew" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."crew_weekly_scores" (
    "id" bigint NOT NULL,
    "crew_id" integer NOT NULL,
    "week_id" "text" NOT NULL,
    "score" integer DEFAULT 0
);


ALTER TABLE "public"."crew_weekly_scores" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."crew_weekly_scores_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."crew_weekly_scores_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."crew_weekly_scores_id_seq" OWNED BY "public"."crew_weekly_scores"."id";



CREATE TABLE IF NOT EXISTS "public"."gps" (
    "gps_id" integer NOT NULL,
    "name" character varying(30),
    "latitude" numeric(9,7),
    "longitude" numeric(9,7)
);


ALTER TABLE "public"."gps" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."register" (
    "register_id" integer NOT NULL,
    "introduction" character varying(300),
    "created_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    "status" "public"."register_status",
    "user_id" integer NOT NULL,
    "crew_id" integer NOT NULL
);


ALTER TABLE "public"."register" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."running_record" (
    "record_id" integer NOT NULL,
    "distance" real,
    "calories" integer,
    "cadence" integer,
    "pace" numeric(5,2),
    "start_time" timestamp with time zone,
    "end_time" timestamp with time zone,
    "user_id" integer NOT NULL,
    "gps_id" integer
);


ALTER TABLE "public"."running_record" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."user" (
    "user_id" integer NOT NULL,
    "name" character varying(30) NOT NULL,
    "age" integer,
    "gender" "public"."user_gender",
    "email" character varying(50) NOT NULL,
    "height" numeric(5,2),
    "weight" numeric(5,2),
    "crew_id" integer,
    "weekly_score" integer DEFAULT 0,
    "total_score" integer DEFAULT 0,
    "auth_user_id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL
);


ALTER TABLE "public"."user" OWNER TO "postgres";


ALTER TABLE ONLY "public"."crew_weekly_scores" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."crew_weekly_scores_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."area"
    ADD CONSTRAINT "area_pkey" PRIMARY KEY ("area_id");



ALTER TABLE ONLY "public"."crew"
    ADD CONSTRAINT "crew_pkey" PRIMARY KEY ("crew_id");



ALTER TABLE ONLY "public"."crew_weekly_scores"
    ADD CONSTRAINT "crew_weekly_scores_crew_id_week_id_key" UNIQUE ("crew_id", "week_id");



ALTER TABLE ONLY "public"."crew_weekly_scores"
    ADD CONSTRAINT "crew_weekly_scores_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."gps"
    ADD CONSTRAINT "gps_pkey" PRIMARY KEY ("gps_id");



ALTER TABLE ONLY "public"."register"
    ADD CONSTRAINT "register_pkey" PRIMARY KEY ("register_id");



ALTER TABLE ONLY "public"."running_record"
    ADD CONSTRAINT "running_record_pkey" PRIMARY KEY ("record_id");



ALTER TABLE ONLY "public"."user"
    ADD CONSTRAINT "user_auth_user_id_key" UNIQUE ("auth_user_id");



ALTER TABLE ONLY "public"."user"
    ADD CONSTRAINT "user_email_key" UNIQUE ("email");



ALTER TABLE ONLY "public"."user"
    ADD CONSTRAINT "user_pkey" PRIMARY KEY ("user_id");



CREATE INDEX "idx_crew_weekly_scores_week_id" ON "public"."crew_weekly_scores" USING "btree" ("week_id");



ALTER TABLE ONLY "public"."crew_weekly_scores"
    ADD CONSTRAINT "crew_weekly_scores_crew_id_fkey" FOREIGN KEY ("crew_id") REFERENCES "public"."crew"("crew_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."crew"
    ADD CONSTRAINT "fk_crew_area" FOREIGN KEY ("area_id") REFERENCES "public"."area"("area_id");



ALTER TABLE ONLY "public"."running_record"
    ADD CONSTRAINT "fk_record_gps" FOREIGN KEY ("gps_id") REFERENCES "public"."gps"("gps_id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."running_record"
    ADD CONSTRAINT "fk_record_user" FOREIGN KEY ("user_id") REFERENCES "public"."user"("user_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."register"
    ADD CONSTRAINT "fk_register_crew" FOREIGN KEY ("crew_id") REFERENCES "public"."crew"("crew_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."register"
    ADD CONSTRAINT "fk_register_user" FOREIGN KEY ("user_id") REFERENCES "public"."user"("user_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user"
    ADD CONSTRAINT "fk_user_auth" FOREIGN KEY ("auth_user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user"
    ADD CONSTRAINT "fk_user_crew" FOREIGN KEY ("crew_id") REFERENCES "public"."crew"("crew_id") ON DELETE SET NULL;



ALTER TABLE "public"."area" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."crew" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."gps" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."register" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."running_record" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."user" ENABLE ROW LEVEL SECURITY;


GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_crew_weekly_score"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_crew_weekly_score"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_crew_weekly_score"() TO "service_role";



GRANT ALL ON TABLE "public"."area" TO "anon";
GRANT ALL ON TABLE "public"."area" TO "authenticated";
GRANT ALL ON TABLE "public"."area" TO "service_role";



GRANT ALL ON TABLE "public"."crew" TO "anon";
GRANT ALL ON TABLE "public"."crew" TO "authenticated";
GRANT ALL ON TABLE "public"."crew" TO "service_role";



GRANT ALL ON TABLE "public"."crew_weekly_scores" TO "anon";
GRANT ALL ON TABLE "public"."crew_weekly_scores" TO "authenticated";
GRANT ALL ON TABLE "public"."crew_weekly_scores" TO "service_role";



GRANT ALL ON SEQUENCE "public"."crew_weekly_scores_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."crew_weekly_scores_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."crew_weekly_scores_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."gps" TO "anon";
GRANT ALL ON TABLE "public"."gps" TO "authenticated";
GRANT ALL ON TABLE "public"."gps" TO "service_role";



GRANT ALL ON TABLE "public"."register" TO "anon";
GRANT ALL ON TABLE "public"."register" TO "authenticated";
GRANT ALL ON TABLE "public"."register" TO "service_role";



GRANT ALL ON TABLE "public"."running_record" TO "anon";
GRANT ALL ON TABLE "public"."running_record" TO "authenticated";
GRANT ALL ON TABLE "public"."running_record" TO "service_role";



GRANT ALL ON TABLE "public"."user" TO "anon";
GRANT ALL ON TABLE "public"."user" TO "authenticated";
GRANT ALL ON TABLE "public"."user" TO "service_role";



ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";







