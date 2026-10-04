-- Oracle PL/SQL package for task search
-- Reference artifact only; does not run against H2.

CREATE OR REPLACE PACKAGE task_search_pkg AS

    TYPE task_record IS RECORD (
        id          NUMBER,
        title       VARCHAR2(255),
        description VARCHAR2(1000),
        status      VARCHAR2(20),
        priority    VARCHAR2(10),
        assignee    VARCHAR2(100),
        created_at  TIMESTAMP
    );

    TYPE task_cursor IS REF CURSOR RETURN task_record;

    PROCEDURE search_tasks(
        p_search_term IN  VARCHAR2 DEFAULT NULL,
        p_status      IN  VARCHAR2 DEFAULT NULL,
        p_page        IN  NUMBER   DEFAULT 1,
        p_page_size   IN  NUMBER   DEFAULT 10,
        p_results     OUT task_cursor,
        p_total_count OUT NUMBER
    );

END task_search_pkg;
/

CREATE OR REPLACE PACKAGE BODY task_search_pkg AS

    PROCEDURE search_tasks(
        p_search_term IN  VARCHAR2 DEFAULT NULL,
        p_status      IN  VARCHAR2 DEFAULT NULL,
        p_page        IN  NUMBER   DEFAULT 1,
        p_page_size   IN  NUMBER   DEFAULT 10,
        p_results     OUT task_cursor,
        p_total_count OUT NUMBER
    ) IS
        v_term   VARCHAR2(257);
        v_offset NUMBER;
    BEGIN
        -- Oracle '' = NULL, so build the LIKE pattern safely.
        IF p_search_term IS NULL OR TRIM(p_search_term) IS NULL THEN
            v_term := '%';
        ELSE
            v_term := '%' || LOWER(TRIM(p_search_term)) || '%';
        END IF;

        -- Guard pagination inputs.
        IF p_page IS NULL OR p_page < 1 THEN p_page := 1; END IF;
        IF p_page_size IS NULL OR p_page_size < 1 THEN p_page_size := 10; END IF;
        IF p_page_size > 100 THEN p_page_size := 100; END IF;

        v_offset := (p_page - 1) * p_page_size;

        -- Total count: parentheses required around OR.
        SELECT COUNT(*)
          INTO p_total_count
          FROM tasks
         WHERE archived = 0
           AND (LOWER(title) LIKE v_term OR LOWER(description) LIKE v_term)
           AND (p_status IS NULL OR status = UPPER(TRIM(p_status)));

        -- Paginated results (pre-12c ROWNUM pattern).
        OPEN p_results FOR
            SELECT id, title, description, status, priority, assignee, created_at
              FROM (
                  SELECT t.*, ROWNUM AS rn
                    FROM (
                        SELECT id, title, description, status, priority,
                               assignee, created_at
                          FROM tasks
                         WHERE archived = 0
                           AND (LOWER(title) LIKE v_term OR LOWER(description) LIKE v_term)
                           AND (p_status IS NULL OR status = UPPER(TRIM(p_status)))
                         ORDER BY created_at DESC, id DESC
                    ) t
                   WHERE ROWNUM <= v_offset + p_page_size
              )
             WHERE rn > v_offset;

    END search_tasks;

END task_search_pkg;
/