


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


CREATE SCHEMA IF NOT EXISTS "auth";


ALTER SCHEMA "auth" OWNER TO "supabase_admin";


CREATE SCHEMA IF NOT EXISTS "public";


ALTER SCHEMA "public" OWNER TO "pg_database_owner";


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE SCHEMA IF NOT EXISTS "storage";


ALTER SCHEMA "storage" OWNER TO "supabase_admin";


CREATE TYPE "auth"."aal_level" AS ENUM (
    'aal1',
    'aal2',
    'aal3'
);


ALTER TYPE "auth"."aal_level" OWNER TO "supabase_auth_admin";


CREATE TYPE "auth"."code_challenge_method" AS ENUM (
    's256',
    'plain'
);


ALTER TYPE "auth"."code_challenge_method" OWNER TO "supabase_auth_admin";


CREATE TYPE "auth"."factor_status" AS ENUM (
    'unverified',
    'verified'
);


ALTER TYPE "auth"."factor_status" OWNER TO "supabase_auth_admin";


CREATE TYPE "auth"."factor_type" AS ENUM (
    'totp',
    'webauthn',
    'phone'
);


ALTER TYPE "auth"."factor_type" OWNER TO "supabase_auth_admin";


CREATE TYPE "auth"."oauth_authorization_status" AS ENUM (
    'pending',
    'approved',
    'denied',
    'expired'
);


ALTER TYPE "auth"."oauth_authorization_status" OWNER TO "supabase_auth_admin";


CREATE TYPE "auth"."oauth_client_type" AS ENUM (
    'public',
    'confidential'
);


ALTER TYPE "auth"."oauth_client_type" OWNER TO "supabase_auth_admin";


CREATE TYPE "auth"."oauth_registration_type" AS ENUM (
    'dynamic',
    'manual'
);


ALTER TYPE "auth"."oauth_registration_type" OWNER TO "supabase_auth_admin";


CREATE TYPE "auth"."oauth_response_type" AS ENUM (
    'code'
);


ALTER TYPE "auth"."oauth_response_type" OWNER TO "supabase_auth_admin";


CREATE TYPE "auth"."one_time_token_type" AS ENUM (
    'confirmation_token',
    'reauthentication_token',
    'recovery_token',
    'email_change_token_new',
    'email_change_token_current',
    'phone_change_token'
);


ALTER TYPE "auth"."one_time_token_type" OWNER TO "supabase_auth_admin";


CREATE TYPE "storage"."buckettype" AS ENUM (
    'STANDARD',
    'ANALYTICS',
    'VECTOR'
);


ALTER TYPE "storage"."buckettype" OWNER TO "supabase_storage_admin";


CREATE OR REPLACE FUNCTION "auth"."email"() RETURNS "text"
    LANGUAGE "sql" STABLE
    AS $$
  select 
  coalesce(
    nullif(current_setting('request.jwt.claim.email', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'email')
  )::text
$$;


ALTER FUNCTION "auth"."email"() OWNER TO "supabase_auth_admin";


COMMENT ON FUNCTION "auth"."email"() IS 'Deprecated. Use auth.jwt() -> ''email'' instead.';



CREATE OR REPLACE FUNCTION "auth"."jwt"() RETURNS "jsonb"
    LANGUAGE "sql" STABLE
    AS $$
  select 
    coalesce(
        nullif(current_setting('request.jwt.claim', true), ''),
        nullif(current_setting('request.jwt.claims', true), '')
    )::jsonb
$$;


ALTER FUNCTION "auth"."jwt"() OWNER TO "supabase_auth_admin";


CREATE OR REPLACE FUNCTION "auth"."role"() RETURNS "text"
    LANGUAGE "sql" STABLE
    AS $$
  select 
  coalesce(
    nullif(current_setting('request.jwt.claim.role', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role')
  )::text
$$;


ALTER FUNCTION "auth"."role"() OWNER TO "supabase_auth_admin";


COMMENT ON FUNCTION "auth"."role"() IS 'Deprecated. Use auth.jwt() -> ''role'' instead.';



CREATE OR REPLACE FUNCTION "auth"."uid"() RETURNS "uuid"
    LANGUAGE "sql" STABLE
    AS $$
  select 
  coalesce(
    nullif(current_setting('request.jwt.claim.sub', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')
  )::uuid
$$;


ALTER FUNCTION "auth"."uid"() OWNER TO "supabase_auth_admin";


COMMENT ON FUNCTION "auth"."uid"() IS 'Deprecated. Use auth.jwt() -> ''sub'' instead.';



CREATE OR REPLACE FUNCTION "public"."alimentar_movim_tanque_transf"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  v_produto_um uuid;
  v_produto_dois uuid;
  v_percentual numeric;
  v_tanque_um uuid;
  v_tanque_dois uuid;
  v_data_mov timestamp;

  v_entrada_amb_um numeric;
  v_entrada_amb_dois numeric;
  v_entrada_vinte_um numeric;
  v_entrada_vinte_dois numeric;

  v_saida_amb_um numeric;
  v_saida_amb_dois numeric;
  v_saida_vinte_um numeric;
  v_saida_vinte_dois numeric;
BEGIN
  v_data_mov := now() at time zone 'America/Sao_Paulo';

  IF NEW.tipo_op <> 'transf' THEN
    RETURN NEW;
  END IF;

  SELECT produto_um, produto_dois
  INTO v_produto_um, v_produto_dois
  FROM public.produtos
  WHERE id = NEW.produto_id;

  -- PRODUTO PURO
  IF v_produto_um IS NULL AND v_produto_dois IS NULL THEN

    -- SAÍDA (origem)
    IF COALESCE(NEW.saida_vinte, 0) > 0 THEN
      SELECT t.id INTO v_tanque_um
      FROM public.tanques t
      WHERE t.id_filial = NEW.filial_origem_id
        AND t.id_produto = NEW.produto_id
        AND t.status = 'Em operação'
      LIMIT 1;

      INSERT INTO public.movimentacoes_tanque (
        movimentacao_id, tanque_id, produto_id, data_mov, cliente, descricao,
        entrada_amb, entrada_vinte, saida_amb, saida_vinte
      )
      VALUES (
        NEW.id, v_tanque_um, NEW.produto_id, v_data_mov, NEW.cliente, NEW.descricao,
        0, 0, COALESCE(NEW.saida_amb, 0), COALESCE(NEW.saida_vinte, 0)
      );
    END IF;

    -- ENTRADA (destino)
    IF COALESCE(NEW.entrada_vinte, 0) > 0 THEN
      SELECT t.id INTO v_tanque_um
      FROM public.tanques t
      WHERE t.id_filial = NEW.filial_destino_id
        AND t.id_produto = NEW.produto_id
        AND t.status = 'Em operação'
      LIMIT 1;

      INSERT INTO public.movimentacoes_tanque (
        movimentacao_id, tanque_id, produto_id, data_mov, cliente, descricao,
        entrada_amb, entrada_vinte, saida_amb, saida_vinte
      )
      VALUES (
        NEW.id, v_tanque_um, NEW.produto_id, v_data_mov, NEW.cliente, NEW.descricao,
        COALESCE(NEW.entrada_amb, 0), COALESCE(NEW.entrada_vinte, 0), 0, 0
      );
    END IF;

    RETURN NEW;
  END IF;

  -- PRODUTO MISTURADO
  SELECT p.percentual
  INTO v_percentual
  FROM public.percentual_mistura p
  WHERE p.produto_id = v_produto_dois
  ORDER BY p.data DESC
  LIMIT 1;

  IF v_percentual IS NULL THEN
    RAISE EXCEPTION 'Percentual de mistura não encontrado para o produto %', v_produto_dois;
  END IF;

  v_entrada_amb_dois   := COALESCE(NEW.entrada_amb, 0)   * (v_percentual / 100);
  v_entrada_amb_um     := COALESCE(NEW.entrada_amb, 0)   - v_entrada_amb_dois;
  v_entrada_vinte_dois := COALESCE(NEW.entrada_vinte, 0) * (v_percentual / 100);
  v_entrada_vinte_um   := COALESCE(NEW.entrada_vinte, 0) - v_entrada_vinte_dois;

  v_saida_amb_dois     := COALESCE(NEW.saida_amb, 0)     * (v_percentual / 100);
  v_saida_amb_um       := COALESCE(NEW.saida_amb, 0)     - v_saida_amb_dois;
  v_saida_vinte_dois   := COALESCE(NEW.saida_vinte, 0)   * (v_percentual / 100);
  v_saida_vinte_um     := COALESCE(NEW.saida_vinte, 0)   - v_saida_vinte_dois;

  -- SAÍDA (origem) - componente 1
  IF COALESCE(NEW.saida_vinte, 0) > 0 THEN
    SELECT t.id INTO v_tanque_um
    FROM public.tanques t
    WHERE t.id_filial = NEW.filial_origem_id
      AND t.id_produto = v_produto_um
      AND t.status = 'Em operação'
    LIMIT 1;

    INSERT INTO public.movimentacoes_tanque (
      movimentacao_id, tanque_id, produto_id, data_mov, cliente, descricao,
      entrada_amb, entrada_vinte, saida_amb, saida_vinte
    )
    VALUES (
      NEW.id, v_tanque_um, v_produto_um, v_data_mov, NEW.cliente, NEW.descricao,
      0, 0, v_saida_amb_um, v_saida_vinte_um
    );

    -- SAÍDA (origem) - componente 2
    SELECT t.id INTO v_tanque_dois
    FROM public.tanques t
    WHERE t.id_filial = NEW.filial_origem_id
      AND t.id_produto = v_produto_dois
      AND t.status = 'Em operação'
    LIMIT 1;

    INSERT INTO public.movimentacoes_tanque (
      movimentacao_id, tanque_id, produto_id, data_mov, cliente, descricao,
      entrada_amb, entrada_vinte, saida_amb, saida_vinte
    )
    VALUES (
      NEW.id, v_tanque_dois, v_produto_dois, v_data_mov, NEW.cliente, NEW.descricao,
      0, 0, v_saida_amb_dois, v_saida_vinte_dois
    );
  END IF;

  -- ENTRADA (destino) - componente 1
  IF COALESCE(NEW.entrada_vinte, 0) > 0 THEN
    SELECT t.id INTO v_tanque_um
    FROM public.tanques t
    WHERE t.id_filial = NEW.filial_destino_id
      AND t.id_produto = v_produto_um
      AND t.status = 'Em operação'
    LIMIT 1;

    INSERT INTO public.movimentacoes_tanque (
      movimentacao_id, tanque_id, produto_id, data_mov, cliente, descricao,
      entrada_amb, entrada_vinte, saida_amb, saida_vinte
    )
    VALUES (
      NEW.id, v_tanque_um, v_produto_um, v_data_mov, NEW.cliente, NEW.descricao,
      v_entrada_amb_um, v_entrada_vinte_um, 0, 0
    );

    -- ENTRADA (destino) - componente 2
    SELECT t.id INTO v_tanque_dois
    FROM public.tanques t
    WHERE t.id_filial = NEW.filial_destino_id
      AND t.id_produto = v_produto_dois
      AND t.status = 'Em operação'
    LIMIT 1;

    INSERT INTO public.movimentacoes_tanque (
      movimentacao_id, tanque_id, produto_id, data_mov, cliente, descricao,
      entrada_amb, entrada_vinte, saida_amb, saida_vinte
    )
    VALUES (
      NEW.id, v_tanque_dois, v_produto_dois, v_data_mov, NEW.cliente, NEW.descricao,
      v_entrada_amb_dois, v_entrada_vinte_dois, 0, 0
    );
  END IF;

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."alimentar_movim_tanque_transf"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."alimentar_saldo_tanque_diario"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  -- Validação do tipo de movimento: apenas 'verificacao' prossegue
  IF NEW.tipo IS DISTINCT FROM 'verificacao' THEN
    RETURN NEW;
  END IF;

  -- Valida se os dados essenciais, incluindo a nova data, estão presentes
  IF NEW.tanque_id IS NULL OR NEW.volume_20_inicial IS NULL OR NEW.data IS NULL THEN
    RETURN NEW;
  END IF;

  -- Executa o Upsert usando a data vinda da coluna NEW.data
  INSERT INTO public.saldo_tanque_diario (
    tanque_id,
    data_mov,
    saldo,
    cacl_id,
    created_at
  )
  VALUES (
    NEW.tanque_id,
    NEW.data,           -- Captura a data diretamente do registro original
    NEW.volume_20_inicial,
    NEW.id,
    now() AT TIME ZONE 'America/Sao_Paulo' -- created_at mantém o registro de inserção
  )
  ON CONFLICT (tanque_id, data_mov) 
  DO UPDATE SET
    saldo = EXCLUDED.saldo,
    cacl_id = EXCLUDED.cacl_id,
    created_at = EXCLUDED.created_at;

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."alimentar_saldo_tanque_diario"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."atualizar_timestamp"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."atualizar_timestamp"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."buscar_volume_tabela"("schema_nome" "text", "tabela_nome" "text", "coluna_cm" "text", "coluna_mm" "text", "altura_cm" integer, "altura_mm" integer DEFAULT 0) RETURNS double precision
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $_$
DECLARE
  valor_cm_raw TEXT;
  valor_mm_raw TEXT;

  valor_cm_litros DOUBLE PRECISION := 0;
  valor_mm_litros DOUBLE PRECISION := 0;
BEGIN
  -- 🔹 CM → litros
  EXECUTE format(
    'SELECT %I::text FROM %I.%I WHERE altura_cm_mm = $1',
    coluna_cm,
    schema_nome,
    tabela_nome
  )
  INTO valor_cm_raw
  USING altura_cm;

  valor_cm_litros :=
    COALESCE(NULLIF(valor_cm_raw, ''), '0')::double precision;

  -- 🔹 MM → mililitros (converter para litros)
  IF altura_mm > 0 THEN
    EXECUTE format(
      'SELECT %I::text FROM %I.%I WHERE altura_cm_mm = $1',
      coluna_mm,
      schema_nome,
      tabela_nome
    )
    INTO valor_mm_raw
    USING altura_mm;

    valor_mm_litros :=
      (COALESCE(NULLIF(valor_mm_raw, ''), '0')::double precision) / 1000.0;
  END IF;

  -- ✅ Soma final em litros
  RETURN valor_cm_litros + valor_mm_litros;
END;
$_$;


ALTER FUNCTION "public"."buscar_volume_tabela"("schema_nome" "text", "tabela_nome" "text", "coluna_cm" "text", "coluna_mm" "text", "altura_cm" integer, "altura_mm" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."buscar_volume_tabela_debug_json"("schema_nome" "text", "tabela_nome" "text", "coluna_cm" "text", "coluna_mm" "text", "altura_cm" integer, "altura_mm" integer DEFAULT 0) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $_$
DECLARE
  valor_cm_raw TEXT;
  valor_mm_raw TEXT;

  valor_cm_litros DOUBLE PRECISION := 0;
  valor_mm_litros DOUBLE PRECISION := 0;

  soma_litros DOUBLE PRECISION := 0;
BEGIN
  -- 🔎 CM → litros
  EXECUTE format(
    'SELECT %I::text FROM %I.%I WHERE altura_cm_mm = $1',
    coluna_cm,
    schema_nome,
    tabela_nome
  )
  INTO valor_cm_raw
  USING altura_cm;

  -- 🔎 MM → mililitros
  IF altura_mm > 0 THEN
    EXECUTE format(
      'SELECT %I::text FROM %I.%I WHERE altura_cm_mm = $1',
      coluna_mm,
      schema_nome,
      tabela_nome
    )
    INTO valor_mm_raw
    USING altura_mm;
  END IF;

  -- ✅ CONVERSÕES CORRETAS
  valor_cm_litros :=
    COALESCE(NULLIF(valor_cm_raw, ''), '0')::double precision;

  -- ⚠️ MM ESTÁ EM MILILITROS → DIVIDE POR 1000
  valor_mm_litros :=
    (COALESCE(NULLIF(valor_mm_raw, ''), '0')::double precision) / 1000.0;

  soma_litros := valor_cm_litros + valor_mm_litros;

  RETURN jsonb_build_object(
    'schema', schema_nome,
    'tabela', tabela_nome,

    'coluna_cm', coluna_cm,
    'altura_cm', altura_cm,
    'valor_cm_raw', valor_cm_raw,
    'valor_cm_litros', valor_cm_litros,

    'coluna_mm', coluna_mm,
    'altura_mm', altura_mm,
    'valor_mm_raw', valor_mm_raw,
    'valor_mm_litros', valor_mm_litros,

    'soma_litros', soma_litros
  );
END;
$_$;


ALTER FUNCTION "public"."buscar_volume_tabela_debug_json"("schema_nome" "text", "tabela_nome" "text", "coluna_cm" "text", "coluna_mm" "text", "altura_cm" integer, "altura_mm" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."definir_tanque_venda_func"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    v_tanque_id uuid;
BEGIN
    -- Verificar se a operação é do tipo 'venda'
    IF NEW.tipo_op = 'venda' THEN
        -- Buscar o ID do tanque que corresponde à filial e produto da movimentação
        SELECT t.id INTO v_tanque_id
        FROM public.tanques t
        WHERE t.id_filial = NEW.filial_id
          AND t.id_produto = NEW.produto_id
        LIMIT 1;
        
        -- Se encontrou um tanque, atualizar a coluna tq_orig
        IF FOUND THEN
            NEW.tq_orig := v_tanque_id;
        END IF;
    END IF;
    
    -- Retornar o registro (modificado ou não)
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."definir_tanque_venda_func"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."excluir_usuario_por_email"("email_input" "text") RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  user_to_delete RECORD;
BEGIN
  SELECT * INTO user_to_delete
  FROM auth.users
  WHERE email = email_input;

  IF user_to_delete.id IS NOT NULL THEN
    DELETE FROM public.usuarios WHERE id = user_to_delete.id;
    PERFORM auth.admin_delete_user(user_to_delete.id);
    RAISE NOTICE 'Usuário % removido com sucesso!', user_to_delete.email;
  ELSE
    RAISE NOTICE 'Usuário com este e-mail não encontrado no Auth.';
  END IF;
END;
$$;


ALTER FUNCTION "public"."excluir_usuario_por_email"("email_input" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."fn_estoque_inicial_tanque"("p_tanque_id" "uuid", "p_data" "date") RETURNS numeric
    LANGUAGE "plpgsql" STABLE
    AS $$
declare
  v_saldo_base numeric;
  v_data_base timestamp;
  v_delta numeric := 0;
  v_inicio_hoje timestamp := (p_data::timestamp);              -- 00:00 do dia D
  v_inicio_ontem timestamp := (p_data::timestamp - interval '1 day'); -- 00:00 do dia D-1
begin
  -- 1) Tentar pegar o FECHAMENTO de ontem (D-1)
  select saldo, data_mov
  into v_saldo_base, v_data_base
  from public.saldo_tanque_diario
  where tanque_id = p_tanque_id
    and data_mov >= v_inicio_ontem
    and data_mov < v_inicio_hoje
  order by data_mov desc
  limit 1;

  -- Se achou o fechamento de ontem, esse é o estoque inicial de hoje
  if found then
    return v_saldo_base;
  end if;

  -- 2) Senão, pegar o último FECHAMENTO disponível antes de ontem
  select saldo, data_mov
  into v_saldo_base, v_data_base
  from public.saldo_tanque_diario
  where tanque_id = p_tanque_id
    and data_mov < v_inicio_ontem
  order by data_mov desc
  limit 1;

  -- Se não existir nenhum fechamento ainda, saldo base = 0
  if v_saldo_base is null then
    v_saldo_base := 0;
    v_data_base := '1970-01-01 00:00:00';
  end if;

  -- 3) Recompõe SOMENTE com movimentações APÓS o fechamento encontrado
  --    e SOMENTE até o fim de ontem (nunca inclui hoje)
  select
    coalesce(sum(entrada_vinte), 0) - coalesce(sum(saida_vinte), 0)
  into v_delta
  from public.movimentacoes_tanque
  where tanque_id = p_tanque_id
    and data_mov > v_data_base
    and data_mov < v_inicio_hoje;

  return v_saldo_base + v_delta;
end;
$$;


ALTER FUNCTION "public"."fn_estoque_inicial_tanque"("p_tanque_id" "uuid", "p_data" "date") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."fn_gerar_movimentacao_tanque"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  v_produto_um uuid;
  v_produto_dois uuid;
  v_percentual numeric;
  v_tanque_um uuid;
  v_tanque_dois uuid;
  v_data_mov timestamp;

  v_entrada_amb_um numeric;
  v_entrada_amb_dois numeric;
  v_entrada_vinte_um numeric;
  v_entrada_vinte_dois numeric;
  v_saida_amb_um numeric;
  v_saida_amb_dois numeric;
  v_saida_vinte_um numeric;
  v_saida_vinte_dois numeric;
BEGIN
  v_data_mov := now() at time zone 'America/Sao_Paulo';

  IF TG_OP = 'UPDATE' THEN
    IF NEW.produto_id = OLD.produto_id AND 
       NEW.entrada_amb = OLD.entrada_amb AND 
       NEW.entrada_vinte = OLD.entrada_vinte AND
       NEW.saida_amb = OLD.saida_amb AND
       NEW.saida_vinte = OLD.saida_vinte AND
       NEW.filial_id = OLD.filial_id THEN
      RETURN NEW;
    END IF;
  END IF;

  SELECT produto_um, produto_dois
  INTO v_produto_um, v_produto_dois
  FROM public.produtos
  WHERE id = NEW.produto_id;

  -- PRODUTO PURO
  IF v_produto_um IS NULL AND v_produto_dois IS NULL THEN
    SELECT t.id INTO v_tanque_um
    FROM public.tanques t
    WHERE t.id_filial = NEW.filial_id
      AND t.id_produto = NEW.produto_id
      AND t.status = 'Em operação'
    LIMIT 1;

    IF v_tanque_um IS NOT NULL THEN
      INSERT INTO public.movimentacoes_tanque (
        movimentacao_id, tanque_id, produto_id, data_mov, cliente, descricao,
        entrada_amb, entrada_vinte, saida_amb, saida_vinte
      )
      VALUES (
        NEW.id, v_tanque_um, NEW.produto_id, v_data_mov, NEW.cliente, NEW.descricao,
        COALESCE(NEW.entrada_amb, 0), COALESCE(NEW.entrada_vinte, 0),
        COALESCE(NEW.saida_amb, 0), COALESCE(NEW.saida_vinte, 0)
      );
    END IF;

    RETURN NEW;
  END IF;

  -- PRODUTO MISTURADO
  SELECT p.percentual INTO v_percentual
  FROM public.percentual_mistura p
  WHERE p.produto_id = v_produto_dois
  ORDER BY p.data DESC
  LIMIT 1;

  IF v_percentual IS NULL THEN
    RAISE EXCEPTION 'Percentual de mistura não encontrado para o produto %', v_produto_dois;
  END IF;

  v_entrada_amb_dois   := COALESCE(NEW.entrada_amb, 0)   * (v_percentual / 100);
  v_entrada_amb_um     := COALESCE(NEW.entrada_amb, 0)   - v_entrada_amb_dois;
  v_entrada_vinte_dois := COALESCE(NEW.entrada_vinte, 0) * (v_percentual / 100);
  v_entrada_vinte_um   := COALESCE(NEW.entrada_vinte, 0) - v_entrada_vinte_dois;

  v_saida_amb_dois     := COALESCE(NEW.saida_amb, 0)     * (v_percentual / 100);
  v_saida_amb_um       := COALESCE(NEW.saida_amb, 0)     - v_saida_amb_dois;
  v_saida_vinte_dois   := COALESCE(NEW.saida_vinte, 0)   * (v_percentual / 100);
  v_saida_vinte_um     := COALESCE(NEW.saida_vinte, 0)   - v_saida_vinte_dois;

  -- componente 1
  SELECT t.id INTO v_tanque_um
  FROM public.tanques t
  WHERE t.id_filial = NEW.filial_id
    AND t.id_produto = v_produto_um
    AND t.status = 'Em operação'
  LIMIT 1;

  IF v_tanque_um IS NOT NULL THEN
    INSERT INTO public.movimentacoes_tanque (
      movimentacao_id, tanque_id, produto_id, data_mov, cliente, descricao,
      entrada_amb, entrada_vinte, saida_amb, saida_vinte
    )
    VALUES (
      NEW.id, v_tanque_um, v_produto_um, v_data_mov, NEW.cliente, NEW.descricao,
      v_entrada_amb_um, v_entrada_vinte_um, v_saida_amb_um, v_saida_vinte_um
    );
  END IF;

  -- componente 2
  SELECT t.id INTO v_tanque_dois
  FROM public.tanques t
  WHERE t.id_filial = NEW.filial_id
    AND t.id_produto = v_produto_dois
    AND t.status = 'Em operação'
  LIMIT 1;

  IF v_tanque_dois IS NOT NULL THEN
    INSERT INTO public.movimentacoes_tanque (
      movimentacao_id, tanque_id, produto_id, data_mov, cliente, descricao,
      entrada_amb, entrada_vinte, saida_amb, saida_vinte
    )
    VALUES (
      NEW.id, v_tanque_dois, v_produto_dois, v_data_mov, NEW.cliente, NEW.descricao,
      v_entrada_amb_dois, v_entrada_vinte_dois, v_saida_amb_dois, v_saida_vinte_dois
    );
  END IF;

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."fn_gerar_movimentacao_tanque"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."fn_gerar_movimentacao_tanque_v2"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
declare
  v_produto_um uuid;
  v_produto_dois uuid;
  v_percentual numeric;

  v_tanque_um uuid;
  v_tanque_dois uuid;

  v_data_mov timestamp;

  v_entrada_amb_um numeric;
  v_entrada_amb_dois numeric;
  v_entrada_vinte_um numeric;
  v_entrada_vinte_dois numeric;
  v_saida_amb_um numeric;
  v_saida_amb_dois numeric;
  v_saida_vinte_um numeric;
  v_saida_vinte_dois numeric;
begin
  if tg_op <> 'INSERT' then
    return new;
  end if;

  if exists (
    select 1
    from public.movimentacoes_tanque
    where movimentacao_id = new.id
  ) then
    return new;
  end if;

  v_data_mov := now() at time zone 'America/Sao_Paulo';

  select produto_um, produto_dois
  into v_produto_um, v_produto_dois
  from public.produtos
  where id = new.produto_id;

  -- ==========================
  -- PRODUTO PURO
  -- ==========================
  if v_produto_um is null and v_produto_dois is null then
    select t.id
    into v_tanque_um
    from public.tanques t
    where t.id_filial = new.filial_id
      and t.id_produto = new.produto_id
      and t.status = 'Em operação'
    limit 1;

    if v_tanque_um is not null then
      insert into public.movimentacoes_tanque (
        movimentacao_id,
        tanque_id,
        produto_id,
        data_mov,
        cliente,
        descricao,
        entrada_amb,
        entrada_vinte,
        saida_amb,
        saida_vinte
      ) values (
        new.id,
        v_tanque_um,
        new.produto_id,
        v_data_mov,
        new.cliente,
        new.descricao,
        coalesce(new.entrada_amb, 0),
        coalesce(new.entrada_vinte, 0),
        coalesce(new.saida_amb, 0),
        coalesce(new.saida_vinte, 0)
      );
    end if;

    return new;
  end if;

  -- ==========================
  -- PRODUTO MISTURADO
  -- ==========================
  select p.percentual
  into v_percentual
  from public.percentual_mistura p
  where p.produto_id = v_produto_dois
  order by p.data desc
  limit 1;

  if v_percentual is null then
    raise exception 'Percentual de mistura não encontrado para o produto %', v_produto_dois;
  end if;

  v_entrada_amb_dois   := coalesce(new.entrada_amb, 0)   * (v_percentual / 100);
  v_entrada_amb_um     := coalesce(new.entrada_amb, 0)   - v_entrada_amb_dois;

  v_entrada_vinte_dois := coalesce(new.entrada_vinte, 0) * (v_percentual / 100);
  v_entrada_vinte_um   := coalesce(new.entrada_vinte, 0) - v_entrada_vinte_dois;

  v_saida_amb_dois     := coalesce(new.saida_amb, 0)     * (v_percentual / 100);
  v_saida_amb_um       := coalesce(new.saida_amb, 0)     - v_saida_amb_dois;

  v_saida_vinte_dois   := coalesce(new.saida_vinte, 0)   * (v_percentual / 100);
  v_saida_vinte_um     := coalesce(new.saida_vinte, 0)   - v_saida_vinte_dois;

  -- Tanque do produto principal
  select t.id
  into v_tanque_um
  from public.tanques t
  where t.id_filial = new.filial_id
    and t.id_produto = v_produto_um
    and t.status = 'Em operação'
  limit 1;

  if v_tanque_um is not null then
    insert into public.movimentacoes_tanque (
      movimentacao_id,
      tanque_id,
      produto_id,
      data_mov,
      cliente,
      descricao,
      entrada_amb,
      entrada_vinte,
      saida_amb,
      saida_vinte
    ) values (
      new.id,
      v_tanque_um,
      v_produto_um,
      v_data_mov,
      new.cliente,
      new.descricao,
      v_entrada_amb_um,
      v_entrada_vinte_um,
      v_saida_amb_um,
      v_saida_vinte_um
    );
  end if;

  -- Tanque do produto da mistura
  select t.id
  into v_tanque_dois
  from public.tanques t
  where t.id_filial = new.filial_id
    and t.id_produto = v_produto_dois
    and t.status = 'Em operação'
  limit 1;

  if v_tanque_dois is not null then
    insert into public.movimentacoes_tanque (
      movimentacao_id,
      tanque_id,
      produto_id,
      data_mov,
      cliente,
      descricao,
      entrada_amb,
      entrada_vinte,
      saida_amb,
      saida_vinte
    ) values (
      new.id,
      v_tanque_dois,
      v_produto_dois,
      v_data_mov,
      new.cliente,
      new.descricao,
      v_entrada_amb_dois,
      v_entrada_vinte_dois,
      v_saida_amb_dois,
      v_saida_vinte_dois
    );
  end if;

  return new;
end;
$$;


ALTER FUNCTION "public"."fn_gerar_movimentacao_tanque_v2"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."gerar_movimentacoes_tanque_func"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
declare
  v_produto_um uuid;
  v_produto_dois uuid;
  v_percentual numeric;

  v_tanque_um uuid;
  v_tanque_dois uuid;

  v_data_mov timestamp;

  v_entrada_amb_um numeric;
  v_entrada_amb_dois numeric;
  v_entrada_vinte_um numeric;
  v_entrada_vinte_dois numeric;
  v_saida_amb_um numeric;
  v_saida_amb_dois numeric;
  v_saida_vinte_um numeric;
  v_saida_vinte_dois numeric;
begin
  if tg_op <> 'INSERT' then
    return new;
  end if;

  if exists (
    select 1
    from public.movimentacoes_tanque
    where movimentacao_id = new.id
  ) then
    return new;
  end if;

  v_data_mov := now() at time zone 'America/Sao_Paulo';

  select produto_um, produto_dois
  into v_produto_um, v_produto_dois
  from public.produtos
  where id = new.produto_id;

  -- ==========================
  -- PRODUTO PURO
  -- ==========================
  if v_produto_um is null and v_produto_dois is null then
    select t.id
    into v_tanque_um
    from public.tanques t
    where t.id_filial = new.filial_id
      and t.id_produto = new.produto_id
      and t.status = 'Em operação'
    limit 1;

    if v_tanque_um is not null then
      insert into public.movimentacoes_tanque (
        movimentacao_id,
        tanque_id,
        produto_id,
        data_mov,
        cliente,
        descricao,
        entrada_amb,
        entrada_vinte,
        saida_amb,
        saida_vinte
      ) values (
        new.id,
        v_tanque_um,
        new.produto_id,
        v_data_mov,
        new.cliente,
        new.descricao,
        coalesce(new.entrada_amb, 0),
        coalesce(new.entrada_vinte, 0),
        coalesce(new.saida_amb, 0),
        coalesce(new.saida_vinte, 0)
      );
    end if;

    return new;
  end if;

  -- ==========================
  -- PRODUTO MISTURADO
  -- ==========================
  select p.percentual
  into v_percentual
  from public.percentual_mistura p
  where p.produto_id = v_produto_dois
  order by p.data desc
  limit 1;

  if v_percentual is null then
    raise exception 'Percentual de mistura não encontrado para o produto %', v_produto_dois;
  end if;

  v_entrada_amb_dois   := coalesce(new.entrada_amb, 0)   * (v_percentual / 100);
  v_entrada_amb_um     := coalesce(new.entrada_amb, 0)   - v_entrada_amb_dois;

  v_entrada_vinte_dois := coalesce(new.entrada_vinte, 0) * (v_percentual / 100);
  v_entrada_vinte_um   := coalesce(new.entrada_vinte, 0) - v_entrada_vinte_dois;

  v_saida_amb_dois     := coalesce(new.saida_amb, 0)     * (v_percentual / 100);
  v_saida_amb_um       := coalesce(new.saida_amb, 0)     - v_saida_amb_dois;

  v_saida_vinte_dois   := coalesce(new.saida_vinte, 0)   * (v_percentual / 100);
  v_saida_vinte_um     := coalesce(new.saida_vinte, 0)   - v_saida_vinte_dois;

  -- Tanque do produto principal
  select t.id
  into v_tanque_um
  from public.tanques t
  where t.id_filial = new.filial_id
    and t.id_produto = v_produto_um
    and t.status = 'Em operação'
  limit 1;

  if v_tanque_um is not null then
    insert into public.movimentacoes_tanque (
      movimentacao_id,
      tanque_id,
      produto_id,
      data_mov,
      cliente,
      descricao,
      entrada_amb,
      entrada_vinte,
      saida_amb,
      saida_vinte
    ) values (
      new.id,
      v_tanque_um,
      v_produto_um,
      v_data_mov,
      new.cliente,
      new.descricao,
      v_entrada_amb_um,
      v_entrada_vinte_um,
      v_saida_amb_um,
      v_saida_vinte_um
    );
  end if;

  -- Tanque do produto da mistura
  select t.id
  into v_tanque_dois
  from public.tanques t
  where t.id_filial = new.filial_id
    and t.id_produto = v_produto_dois
    and t.status = 'Em operação'
  limit 1;

  if v_tanque_dois is not null then
    insert into public.movimentacoes_tanque (
      movimentacao_id,
      tanque_id,
      produto_id,
      data_mov,
      cliente,
      descricao,
      entrada_amb,
      entrada_vinte,
      saida_amb,
      saida_vinte
    ) values (
      new.id,
      v_tanque_dois,
      v_produto_dois,
      v_data_mov,
      new.cliente,
      new.descricao,
      v_entrada_amb_dois,
      v_entrada_vinte_dois,
      v_saida_amb_dois,
      v_saida_vinte_dois
    );
  end if;

  return new;
end;
$$;


ALTER FUNCTION "public"."gerar_movimentacoes_tanque_func"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."gerar_numero_controle"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    prefixo_tipo VARCHAR(3);
    uuid_sem_hifens TEXT;
    ultimos_4_chars VARCHAR(4);
    campo_vazio BOOLEAN;
BEGIN
    -- Verifica qual campo está vazio baseado na tabela
    IF TG_TABLE_NAME = 'cacl' THEN
        campo_vazio := (NEW.numero_controle IS NULL OR TRIM(NEW.numero_controle) = '');
    ELSIF TG_TABLE_NAME = 'ordens_analises' THEN
        campo_vazio := (NEW.numero_controle IS NULL OR TRIM(NEW.numero_controle) = '');
    ELSIF TG_TABLE_NAME = 'ordens' THEN
        campo_vazio := (NEW.n_controle IS NULL OR TRIM(NEW.n_controle) = '');
    ELSE
        campo_vazio := FALSE;
    END IF;
    
    -- Só gera se o campo estiver vazio
    IF campo_vazio THEN
        -- Garante que o ID existe
        IF NEW.id IS NULL THEN
            NEW.id := gen_random_uuid();
        END IF;
        
        -- Prepara o UUID
        uuid_sem_hifens := REPLACE(NEW.id::text, '-', '');
        ultimos_4_chars := UPPER(RIGHT(uuid_sem_hifens, 4));
        
        -- Define prefixo baseado na tabela
        IF TG_TABLE_NAME = 'cacl' THEN
            prefixo_tipo := 'C-';  -- Prefixo para CACL
        
        ELSIF TG_TABLE_NAME = 'ordens_analises' THEN
            IF UPPER(NEW.tipo_operacao) = 'CARGA' THEN
                prefixo_tipo := 'OC-';
            ELSIF UPPER(NEW.tipo_operacao) = 'DESCARGA' THEN
                prefixo_tipo := 'OD-';
            ELSE
                prefixo_tipo := 'OX-';
            END IF;
        
        ELSIF TG_TABLE_NAME = 'ordens' THEN
            prefixo_tipo := 'OD-';  -- Prefixo fixo para ordens
        
        ELSE
            prefixo_tipo := 'X-';
        END IF;
        
        -- Atribui o número de controle à coluna correta
        IF TG_TABLE_NAME = 'cacl' THEN
            NEW.numero_controle := prefixo_tipo || ultimos_4_chars;
        ELSIF TG_TABLE_NAME = 'ordens_analises' THEN
            NEW.numero_controle := prefixo_tipo || ultimos_4_chars;
        ELSIF TG_TABLE_NAME = 'ordens' THEN
            NEW.n_controle := prefixo_tipo || ultimos_4_chars;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."gerar_numero_controle"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."test_trigger_simples"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
    tipo_movimentacao integer;
BEGIN
    -- Determinar o tipo de movimentação (1 para transf, 2 para venda)
    IF NEW.tipo_op = 'transf' THEN
        tipo_movimentacao := 1;
    ELSIF NEW.tipo_op = 'venda' THEN
        tipo_movimentacao := 2;
    ELSE
        tipo_movimentacao := 0; -- Para outros tipos
    END IF;
    
    -- Inserir apenas os campos solicitados
    INSERT INTO movimentacoes_tanque (
        movimentacao_id,
        saida_vinte,
        descricao  -- Vamos usar a descrição para guardar o tipo_movimentacao
    ) VALUES (
        NEW.id,
        NEW.saida_vinte,
        'tipo_' || tipo_movimentacao  -- Ex: 'tipo_1' para transf, 'tipo_2' para venda
    );
    
    RAISE NOTICE 'Trigger executada! ID: %, tipo_op: %, valor: %', 
        NEW.id, NEW.tipo_op, tipo_movimentacao;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."test_trigger_simples"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trigger_inserir_saldo_tanque_diario"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
declare
  data_brasilia timestamp;
begin
  if new.tipo is distinct from 'verificacao' then
    return new;
  end if;

  if new.tanque_id is null then
    return new;
  end if;

  if new.volume_20_inicial is null then
    return new;
  end if;

  -- horário atual fixo em GMT-3 (Brasília)
  data_brasilia := (now() at time zone 'America/Sao_Paulo');

  insert into public.saldo_tanque_diario (
    tanque_id,
    data_mov,
    saldo,
    cacl_id,
    created_at
  )
  values (
    new.tanque_id,
    data_brasilia,
    new.volume_20_inicial,
    new.id,
    data_brasilia
  )
  on conflict (tanque_id, data_mov) 
  do update set
    saldo = excluded.saldo,
    cacl_id = excluded.cacl_id,
    created_at = excluded.created_at;

  return new;
end;
$$;


ALTER FUNCTION "public"."trigger_inserir_saldo_tanque_diario"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."trigger_inserir_saldo_tanque_diario"() IS 'Trigger que insere/atualiza saldo_tanque_diario quando um CACL de verificação é inserido ou atualizado. Usa a data do CACL como referência para data_mov.';



CREATE OR REPLACE FUNCTION "public"."trigger_movimentacoes_tanque"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
declare
  v_produto_um uuid;
  v_produto_dois uuid;
  v_percentual numeric;
  v_qtd_produto_dois numeric;
  v_qtd_produto_um numeric;
  v_tanque_um uuid;
  v_tanque_dois uuid;
  v_exists boolean;
begin
  -- Log para debug (remover em produção)
  RAISE NOTICE 'Trigger executada para movimentacao_id: %, operação: %', NEW.id, TG_OP;
  
  -- Tratar INSERT
  if TG_OP = 'INSERT' then
    
    -- Verificar se já existem registros para esta movimentação
    if exists (
      select 1
      from public.movimentacoes_tanque
      where movimentacao_id = new.id
    ) then
      RAISE NOTICE 'Registros já existem para movimentacao_id: %', NEW.id;
      return new;
    end if;

    RAISE NOTICE 'Processando INSERT para movimentacao_id: %', NEW.id;
    
    -- Continuar com a lógica existente...
    select produto_um, produto_dois
    into v_produto_um, v_produto_dois
    from public.produtos
    where id = new.produto_id;

    -- Produto puro
    if v_produto_um is null and v_produto_dois is null then
      RAISE NOTICE 'Produto puro: %', NEW.produto_id;

      select t.id
      into v_tanque_um
      from public.tanques t
      where t.id_filial = new.filial_id
        and t.id_produto = new.produto_id
        and t.status = 'Em operação'
      limit 1;

      if v_tanque_um is not null then
        RAISE NOTICE 'Inserindo em movimentacoes_tanque: tanque_id %, quantidade %', v_tanque_um, coalesce(new.quantidade, 0);
        
        insert into public.movimentacoes_tanque (
          movimentacao_id,
          tanque_id,
          produto_id,
          quantidade,
          data_mov  -- ALTERAÇÃO: ts_mov substituído por data_mov
        ) values (
          new.id,
          v_tanque_um,
          new.produto_id,
          coalesce(new.quantidade, 0),
          new.data_mov  -- ALTERAÇÃO: ts_mov substituído por data_mov
        );
      else
        RAISE NOTICE 'Nenhum tanque encontrado para o produto % na filial %', NEW.produto_id, NEW.filial_id;
      end if;

      return new;
    end if;

    -- Produto composto
    RAISE NOTICE 'Produto composto: produto_um %, produto_dois %', v_produto_um, v_produto_dois;
    
    select p.percentual
    into v_percentual
    from public.percentual_mistura p
    where p.produto_id = v_produto_dois
    order by p.data desc
    limit 1;

    if v_percentual is null then
      RAISE EXCEPTION 'Percentual de mistura não encontrado para o produto %', v_produto_dois;
    end if;

    v_qtd_produto_dois := coalesce(new.quantidade, 0) * (v_percentual / 100);
    v_qtd_produto_um := coalesce(new.quantidade, 0) - v_qtd_produto_dois;

    RAISE NOTICE 'Quantidades: principal=%, mistura=%, percentual=%', v_qtd_produto_um, v_qtd_produto_dois, v_percentual;

    -- Tanque do produto principal
    select t.id
    into v_tanque_um
    from public.tanques t
    where t.id_filial = new.filial_id
      and t.id_produto = v_produto_um
      and t.status = 'Em operação'
    limit 1;

    if v_tanque_um is not null then
      RAISE NOTICE 'Inserindo produto principal: tanque_id %, quantidade %', v_tanque_um, v_qtd_produto_um;
      
      insert into public.movimentacoes_tanque (
        movimentacao_id,
        tanque_id,
        produto_id,
        quantidade,
        data_mov  -- ALTERAÇÃO: ts_mov substituído por data_mov
      ) values (
        new.id,
        v_tanque_um,
        v_produto_um,
        v_qtd_produto_um,
        new.data_mov  -- ALTERAÇÃO: ts_mov substituído por data_mov
      );
    end if;

    -- Tanque do produto da mistura
    select t.id
    into v_tanque_dois
    from public.tanques t
    where t.id_filial = new.filial_id
      and t.id_produto = v_produto_dois
      and t.status = 'Em operação'
    limit 1;

    if v_tanque_dois is not null then
      RAISE NOTICE 'Inserindo produto mistura: tanque_id %, quantidade %', v_tanque_dois, v_qtd_produto_dois;
      
      insert into public.movimentacoes_tanque (
        movimentacao_id,
        tanque_id,
        produto_id,
        quantidade,
        data_mov  -- ALTERAÇÃO: ts_mov substituído por data_mov
      ) values (
        new.id,
        v_tanque_dois,
        v_produto_dois,
        v_qtd_produto_dois,
        new.data_mov  -- ALTERAÇÃO: ts_mov substituído por data_mov
      );
    end if;

    return new;
  
  -- Tratar UPDATE
  elsif TG_OP = 'UPDATE' then
    
    RAISE NOTICE 'Processando UPDATE para movimentacao_id: %', NEW.id;
    RAISE NOTICE 'OLD: produto_id=%, quantidade=%, filial_id=%, data_mov=%', 
      OLD.produto_id, OLD.quantidade, OLD.filial_id, OLD.data_mov;
    RAISE NOTICE 'NEW: produto_id=%, quantidade=%, filial_id=%, data_mov=%', 
      NEW.produto_id, NEW.quantidade, NEW.filial_id, NEW.data_mov;
    
    -- Verificar se os campos relevantes foram alterados
    if new.produto_id = old.produto_id and 
       new.quantidade = old.quantidade and 
       new.filial_id = old.filial_id and 
       new.data_mov = old.data_mov then  -- ALTERAÇÃO: ts_mov substituído por data_mov
      RAISE NOTICE 'Nenhuma mudança relevante detectada, retornando';
      return new;
    end if;

    RAISE NOTICE 'Mudanças detectadas, atualizando movimentacoes_tanque';

    -- Deletar registros existentes
    delete from public.movimentacoes_tanque
    where movimentacao_id = new.id;
    
    RAISE NOTICE 'Registros antigos deletados para movimentacao_id: %', NEW.id;

    -- Recriar com os novos dados (mesma lógica do INSERT)
    select produto_um, produto_dois
    into v_produto_um, v_produto_dois
    from public.produtos
    where id = new.produto_id;

    -- Produto puro
    if v_produto_um is null and v_produto_dois is null then
      RAISE NOTICE 'Produto puro (UPDATE): %', NEW.produto_id;

      select t.id
      into v_tanque_um
      from public.tanques t
      where t.id_filial = new.filial_id
        and t.id_produto = new.produto_id
        and t.status = 'Em operação'
      limit 1;

      if v_tanque_um is not null then
        RAISE NOTICE 'Inserindo (UPDATE): tanque_id %, quantidade %', v_tanque_um, coalesce(new.quantidade, 0);
        
        insert into public.movimentacoes_tanque (
          movimentacao_id,
          tanque_id,
          produto_id,
          quantidade,
          data_mov  -- ALTERAÇÃO: ts_mov substituído por data_mov
        ) values (
          new.id,
          v_tanque_um,
          new.produto_id,
          coalesce(new.quantidade, 0),
          new.data_mov  -- ALTERAÇÃO: ts_mov substituído por data_mov
        );
      end if;

      return new;
    end if;

    -- Produto composto
    RAISE NOTICE 'Produto composto (UPDATE): produto_um %, produto_dois %', v_produto_um, v_produto_dois;
    
    select p.percentual
    into v_percentual
    from public.percentual_mistura p
    where p.produto_id = v_produto_dois
    order by p.data desc
    limit 1;

    if v_percentual is null then
      RAISE EXCEPTION 'Percentual de mistura não encontrado para o produto %', v_produto_dois;
    end if;

    v_qtd_produto_dois := coalesce(new.quantidade, 0) * (v_percentual / 100);
    v_qtd_produto_um := coalesce(new.quantidade, 0) - v_qtd_produto_dois;

    RAISE NOTICE 'Quantidades (UPDATE): principal=%, mistura=%, percentual=%', v_qtd_produto_um, v_qtd_produto_dois, v_percentual;

    -- Tanque do produto principal
    select t.id
    into v_tanque_um
    from public.tanques t
    where t.id_filial = new.filial_id
      and t.id_produto = v_produto_um
      and t.status = 'Em operação'
    limit 1;

    if v_tanque_um is not null then
      RAISE NOTICE 'Inserindo produto principal (UPDATE): tanque_id %, quantidade %', v_tanque_um, v_qtd_produto_um;
      
      insert into public.movimentacoes_tanque (
        movimentacao_id,
        tanque_id,
        produto_id,
        quantidade,
        data_mov  -- ALTERAÇÃO: ts_mov substituído por data_mov
      ) values (
        new.id,
        v_tanque_um,
        v_produto_um,
        v_qtd_produto_um,
        new.data_mov  -- ALTERAÇÃO: ts_mov substituído por data_mov
      );
    end if;

    -- Tanque do produto da mistura
    select t.id
    into v_tanque_dois
    from public.tanques t
    where t.id_filial = new.filial_id
      and t.id_produto = v_produto_dois
      and t.status = 'Em operação'
    limit 1;

    if v_tanque_dois is not null then
      RAISE NOTICE 'Inserindo produto mistura (UPDATE): tanque_id %, quantidade %', v_tanque_dois, v_qtd_produto_dois;
      
      insert into public.movimentacoes_tanque (
        movimentacao_id,
        tanque_id,
        produto_id,
        quantidade,
        data_mov  -- ALTERAÇÃO: ts_mov substituído por data_mov
      ) values (
        new.id,
        v_tanque_dois,
        v_produto_dois,
        v_qtd_produto_dois,
        new.data_mov  -- ALTERAÇÃO: ts_mov substituído por data_mov
      );
    end if;

    return new;
  end if;
  
  return new;
end;
$$;


ALTER FUNCTION "public"."trigger_movimentacoes_tanque"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_atualizado_em"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    NEW.atualizado_em = NOW();
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_atualizado_em"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."usuario_nivel3"() RETURNS boolean
    LANGUAGE "sql"
    AS $$
  SELECT EXISTS (
    SELECT 1 FROM usuarios
    WHERE email = auth.email()
    AND nivel = 3
  );
$$;


ALTER FUNCTION "public"."usuario_nivel3"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "storage"."can_insert_object"("bucketid" "text", "name" "text", "owner" "uuid", "metadata" "jsonb") RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  INSERT INTO "storage"."objects" ("bucket_id", "name", "owner", "metadata") VALUES (bucketid, name, owner, metadata);
  -- hack to rollback the successful insert
  RAISE sqlstate 'PT200' using
  message = 'ROLLBACK',
  detail = 'rollback successful insert';
END
$$;


ALTER FUNCTION "storage"."can_insert_object"("bucketid" "text", "name" "text", "owner" "uuid", "metadata" "jsonb") OWNER TO "supabase_storage_admin";


CREATE OR REPLACE FUNCTION "storage"."delete_leaf_prefixes"("bucket_ids" "text"[], "names" "text"[]) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_rows_deleted integer;
BEGIN
    LOOP
        WITH candidates AS (
            SELECT DISTINCT
                t.bucket_id,
                unnest(storage.get_prefixes(t.name)) AS name
            FROM unnest(bucket_ids, names) AS t(bucket_id, name)
        ),
        uniq AS (
             SELECT
                 bucket_id,
                 name,
                 storage.get_level(name) AS level
             FROM candidates
             WHERE name <> ''
             GROUP BY bucket_id, name
        ),
        leaf AS (
             SELECT
                 p.bucket_id,
                 p.name,
                 p.level
             FROM storage.prefixes AS p
                  JOIN uniq AS u
                       ON u.bucket_id = p.bucket_id
                           AND u.name = p.name
                           AND u.level = p.level
             WHERE NOT EXISTS (
                 SELECT 1
                 FROM storage.objects AS o
                 WHERE o.bucket_id = p.bucket_id
                   AND o.level = p.level + 1
                   AND o.name COLLATE "C" LIKE p.name || '/%'
             )
             AND NOT EXISTS (
                 SELECT 1
                 FROM storage.prefixes AS c
                 WHERE c.bucket_id = p.bucket_id
                   AND c.level = p.level + 1
                   AND c.name COLLATE "C" LIKE p.name || '/%'
             )
        )
        DELETE
        FROM storage.prefixes AS p
            USING leaf AS l
        WHERE p.bucket_id = l.bucket_id
          AND p.name = l.name
          AND p.level = l.level;

        GET DIAGNOSTICS v_rows_deleted = ROW_COUNT;
        EXIT WHEN v_rows_deleted = 0;
    END LOOP;
END;
$$;


ALTER FUNCTION "storage"."delete_leaf_prefixes"("bucket_ids" "text"[], "names" "text"[]) OWNER TO "supabase_storage_admin";


CREATE OR REPLACE FUNCTION "storage"."enforce_bucket_name_length"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
    if length(new.name) > 100 then
        raise exception 'bucket name "%" is too long (% characters). Max is 100.', new.name, length(new.name);
    end if;
    return new;
end;
$$;


ALTER FUNCTION "storage"."enforce_bucket_name_length"() OWNER TO "supabase_storage_admin";


CREATE OR REPLACE FUNCTION "storage"."extension"("name" "text") RETURNS "text"
    LANGUAGE "plpgsql" IMMUTABLE
    AS $$
DECLARE
    _parts text[];
    _filename text;
BEGIN
    SELECT string_to_array(name, '/') INTO _parts;
    SELECT _parts[array_length(_parts,1)] INTO _filename;
    RETURN reverse(split_part(reverse(_filename), '.', 1));
END
$$;


ALTER FUNCTION "storage"."extension"("name" "text") OWNER TO "supabase_storage_admin";


CREATE OR REPLACE FUNCTION "storage"."filename"("name" "text") RETURNS "text"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
_parts text[];
BEGIN
	select string_to_array(name, '/') into _parts;
	return _parts[array_length(_parts,1)];
END
$$;


ALTER FUNCTION "storage"."filename"("name" "text") OWNER TO "supabase_storage_admin";


CREATE OR REPLACE FUNCTION "storage"."foldername"("name" "text") RETURNS "text"[]
    LANGUAGE "plpgsql" IMMUTABLE
    AS $$
DECLARE
    _parts text[];
BEGIN
    -- Split on "/" to get path segments
    SELECT string_to_array(name, '/') INTO _parts;
    -- Return everything except the last segment
    RETURN _parts[1 : array_length(_parts,1) - 1];
END
$$;


ALTER FUNCTION "storage"."foldername"("name" "text") OWNER TO "supabase_storage_admin";


CREATE OR REPLACE FUNCTION "storage"."get_common_prefix"("p_key" "text", "p_prefix" "text", "p_delimiter" "text") RETURNS "text"
    LANGUAGE "sql" IMMUTABLE
    AS $$
SELECT CASE
    WHEN position(p_delimiter IN substring(p_key FROM length(p_prefix) + 1)) > 0
    THEN left(p_key, length(p_prefix) + position(p_delimiter IN substring(p_key FROM length(p_prefix) + 1)))
    ELSE NULL
END;
$$;


ALTER FUNCTION "storage"."get_common_prefix"("p_key" "text", "p_prefix" "text", "p_delimiter" "text") OWNER TO "supabase_storage_admin";


CREATE OR REPLACE FUNCTION "storage"."get_level"("name" "text") RETURNS integer
    LANGUAGE "sql" IMMUTABLE STRICT
    AS $$
SELECT array_length(string_to_array("name", '/'), 1);
$$;


ALTER FUNCTION "storage"."get_level"("name" "text") OWNER TO "supabase_storage_admin";


CREATE OR REPLACE FUNCTION "storage"."get_prefix"("name" "text") RETURNS "text"
    LANGUAGE "sql" IMMUTABLE STRICT
    AS $_$
SELECT
    CASE WHEN strpos("name", '/') > 0 THEN
             regexp_replace("name", '[\/]{1}[^\/]+\/?$', '')
         ELSE
             ''
        END;
$_$;


ALTER FUNCTION "storage"."get_prefix"("name" "text") OWNER TO "supabase_storage_admin";


CREATE OR REPLACE FUNCTION "storage"."get_prefixes"("name" "text") RETURNS "text"[]
    LANGUAGE "plpgsql" IMMUTABLE STRICT
    AS $$
DECLARE
    parts text[];
    prefixes text[];
    prefix text;
BEGIN
    -- Split the name into parts by '/'
    parts := string_to_array("name", '/');
    prefixes := '{}';

    -- Construct the prefixes, stopping one level below the last part
    FOR i IN 1..array_length(parts, 1) - 1 LOOP
            prefix := array_to_string(parts[1:i], '/');
            prefixes := array_append(prefixes, prefix);
    END LOOP;

    RETURN prefixes;
END;
$$;


ALTER FUNCTION "storage"."get_prefixes"("name" "text") OWNER TO "supabase_storage_admin";


CREATE OR REPLACE FUNCTION "storage"."get_size_by_bucket"() RETURNS TABLE("size" bigint, "bucket_id" "text")
    LANGUAGE "plpgsql" STABLE
    AS $$
BEGIN
    return query
        select sum((metadata->>'size')::bigint) as size, obj.bucket_id
        from "storage".objects as obj
        group by obj.bucket_id;
END
$$;


ALTER FUNCTION "storage"."get_size_by_bucket"() OWNER TO "supabase_storage_admin";


CREATE OR REPLACE FUNCTION "storage"."list_multipart_uploads_with_delimiter"("bucket_id" "text", "prefix_param" "text", "delimiter_param" "text", "max_keys" integer DEFAULT 100, "next_key_token" "text" DEFAULT ''::"text", "next_upload_token" "text" DEFAULT ''::"text") RETURNS TABLE("key" "text", "id" "text", "created_at" timestamp with time zone)
    LANGUAGE "plpgsql"
    AS $_$
BEGIN
    RETURN QUERY EXECUTE
        'SELECT DISTINCT ON(key COLLATE "C") * from (
            SELECT
                CASE
                    WHEN position($2 IN substring(key from length($1) + 1)) > 0 THEN
                        substring(key from 1 for length($1) + position($2 IN substring(key from length($1) + 1)))
                    ELSE
                        key
                END AS key, id, created_at
            FROM
                storage.s3_multipart_uploads
            WHERE
                bucket_id = $5 AND
                key ILIKE $1 || ''%'' AND
                CASE
                    WHEN $4 != '''' AND $6 = '''' THEN
                        CASE
                            WHEN position($2 IN substring(key from length($1) + 1)) > 0 THEN
                                substring(key from 1 for length($1) + position($2 IN substring(key from length($1) + 1))) COLLATE "C" > $4
                            ELSE
                                key COLLATE "C" > $4
                            END
                    ELSE
                        true
                END AND
                CASE
                    WHEN $6 != '''' THEN
                        id COLLATE "C" > $6
                    ELSE
                        true
                    END
            ORDER BY
                key COLLATE "C" ASC, created_at ASC) as e order by key COLLATE "C" LIMIT $3'
        USING prefix_param, delimiter_param, max_keys, next_key_token, bucket_id, next_upload_token;
END;
$_$;


ALTER FUNCTION "storage"."list_multipart_uploads_with_delimiter"("bucket_id" "text", "prefix_param" "text", "delimiter_param" "text", "max_keys" integer, "next_key_token" "text", "next_upload_token" "text") OWNER TO "supabase_storage_admin";


CREATE OR REPLACE FUNCTION "storage"."list_objects_with_delimiter"("_bucket_id" "text", "prefix_param" "text", "delimiter_param" "text", "max_keys" integer DEFAULT 100, "start_after" "text" DEFAULT ''::"text", "next_token" "text" DEFAULT ''::"text", "sort_order" "text" DEFAULT 'asc'::"text") RETURNS TABLE("name" "text", "id" "uuid", "metadata" "jsonb", "updated_at" timestamp with time zone, "created_at" timestamp with time zone, "last_accessed_at" timestamp with time zone)
    LANGUAGE "plpgsql" STABLE
    AS $_$
DECLARE
    v_peek_name TEXT;
    v_current RECORD;
    v_common_prefix TEXT;

    -- Configuration
    v_is_asc BOOLEAN;
    v_prefix TEXT;
    v_start TEXT;
    v_upper_bound TEXT;
    v_file_batch_size INT;

    -- Seek state
    v_next_seek TEXT;
    v_count INT := 0;

    -- Dynamic SQL for batch query only
    v_batch_query TEXT;

BEGIN
    -- ========================================================================
    -- INITIALIZATION
    -- ========================================================================
    v_is_asc := lower(coalesce(sort_order, 'asc')) = 'asc';
    v_prefix := coalesce(prefix_param, '');
    v_start := CASE WHEN coalesce(next_token, '') <> '' THEN next_token ELSE coalesce(start_after, '') END;
    v_file_batch_size := LEAST(GREATEST(max_keys * 2, 100), 1000);

    -- Calculate upper bound for prefix filtering (bytewise, using COLLATE "C")
    IF v_prefix = '' THEN
        v_upper_bound := NULL;
    ELSIF right(v_prefix, 1) = delimiter_param THEN
        v_upper_bound := left(v_prefix, -1) || chr(ascii(delimiter_param) + 1);
    ELSE
        v_upper_bound := left(v_prefix, -1) || chr(ascii(right(v_prefix, 1)) + 1);
    END IF;

    -- Build batch query (dynamic SQL - called infrequently, amortized over many rows)
    IF v_is_asc THEN
        IF v_upper_bound IS NOT NULL THEN
            v_batch_query := 'SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata ' ||
                'FROM storage.objects o WHERE o.bucket_id = $1 AND o.name COLLATE "C" >= $2 ' ||
                'AND o.name COLLATE "C" < $3 ORDER BY o.name COLLATE "C" ASC LIMIT $4';
        ELSE
            v_batch_query := 'SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata ' ||
                'FROM storage.objects o WHERE o.bucket_id = $1 AND o.name COLLATE "C" >= $2 ' ||
                'ORDER BY o.name COLLATE "C" ASC LIMIT $4';
        END IF;
    ELSE
        IF v_upper_bound IS NOT NULL THEN
            v_batch_query := 'SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata ' ||
                'FROM storage.objects o WHERE o.bucket_id = $1 AND o.name COLLATE "C" < $2 ' ||
                'AND o.name COLLATE "C" >= $3 ORDER BY o.name COLLATE "C" DESC LIMIT $4';
        ELSE
            v_batch_query := 'SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata ' ||
                'FROM storage.objects o WHERE o.bucket_id = $1 AND o.name COLLATE "C" < $2 ' ||
                'ORDER BY o.name COLLATE "C" DESC LIMIT $4';
        END IF;
    END IF;

    -- ========================================================================
    -- SEEK INITIALIZATION: Determine starting position
    -- ========================================================================
    IF v_start = '' THEN
        IF v_is_asc THEN
            v_next_seek := v_prefix;
        ELSE
            -- DESC without cursor: find the last item in range
            IF v_upper_bound IS NOT NULL THEN
                SELECT o.name INTO v_next_seek FROM storage.objects o
                WHERE o.bucket_id = _bucket_id AND o.name COLLATE "C" >= v_prefix AND o.name COLLATE "C" < v_upper_bound
                ORDER BY o.name COLLATE "C" DESC LIMIT 1;
            ELSIF v_prefix <> '' THEN
                SELECT o.name INTO v_next_seek FROM storage.objects o
                WHERE o.bucket_id = _bucket_id AND o.name COLLATE "C" >= v_prefix
                ORDER BY o.name COLLATE "C" DESC LIMIT 1;
            ELSE
                SELECT o.name INTO v_next_seek FROM storage.objects o
                WHERE o.bucket_id = _bucket_id
                ORDER BY o.name COLLATE "C" DESC LIMIT 1;
            END IF;

            IF v_next_seek IS NOT NULL THEN
                v_next_seek := v_next_seek || delimiter_param;
            ELSE
                RETURN;
            END IF;
        END IF;
    ELSE
        -- Cursor provided: determine if it refers to a folder or leaf
        IF EXISTS (
            SELECT 1 FROM storage.objects o
            WHERE o.bucket_id = _bucket_id
              AND o.name COLLATE "C" LIKE v_start || delimiter_param || '%'
            LIMIT 1
        ) THEN
            -- Cursor refers to a folder
            IF v_is_asc THEN
                v_next_seek := v_start || chr(ascii(delimiter_param) + 1);
            ELSE
                v_next_seek := v_start || delimiter_param;
            END IF;
        ELSE
            -- Cursor refers to a leaf object
            IF v_is_asc THEN
                v_next_seek := v_start || delimiter_param;
            ELSE
                v_next_seek := v_start;
            END IF;
        END IF;
    END IF;

    -- ========================================================================
    -- MAIN LOOP: Hybrid peek-then-batch algorithm
    -- Uses STATIC SQL for peek (hot path) and DYNAMIC SQL for batch
    -- ========================================================================
    LOOP
        EXIT WHEN v_count >= max_keys;

        -- STEP 1: PEEK using STATIC SQL (plan cached, very fast)
        IF v_is_asc THEN
            IF v_upper_bound IS NOT NULL THEN
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = _bucket_id AND o.name COLLATE "C" >= v_next_seek AND o.name COLLATE "C" < v_upper_bound
                ORDER BY o.name COLLATE "C" ASC LIMIT 1;
            ELSE
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = _bucket_id AND o.name COLLATE "C" >= v_next_seek
                ORDER BY o.name COLLATE "C" ASC LIMIT 1;
            END IF;
        ELSE
            IF v_upper_bound IS NOT NULL THEN
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = _bucket_id AND o.name COLLATE "C" < v_next_seek AND o.name COLLATE "C" >= v_prefix
                ORDER BY o.name COLLATE "C" DESC LIMIT 1;
            ELSIF v_prefix <> '' THEN
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = _bucket_id AND o.name COLLATE "C" < v_next_seek AND o.name COLLATE "C" >= v_prefix
                ORDER BY o.name COLLATE "C" DESC LIMIT 1;
            ELSE
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = _bucket_id AND o.name COLLATE "C" < v_next_seek
                ORDER BY o.name COLLATE "C" DESC LIMIT 1;
            END IF;
        END IF;

        EXIT WHEN v_peek_name IS NULL;

        -- STEP 2: Check if this is a FOLDER or FILE
        v_common_prefix := storage.get_common_prefix(v_peek_name, v_prefix, delimiter_param);

        IF v_common_prefix IS NOT NULL THEN
            -- FOLDER: Emit and skip to next folder (no heap access needed)
            name := rtrim(v_common_prefix, delimiter_param);
            id := NULL;
            updated_at := NULL;
            created_at := NULL;
            last_accessed_at := NULL;
            metadata := NULL;
            RETURN NEXT;
            v_count := v_count + 1;

            -- Advance seek past the folder range
            IF v_is_asc THEN
                v_next_seek := left(v_common_prefix, -1) || chr(ascii(delimiter_param) + 1);
            ELSE
                v_next_seek := v_common_prefix;
            END IF;
        ELSE
            -- FILE: Batch fetch using DYNAMIC SQL (overhead amortized over many rows)
            -- For ASC: upper_bound is the exclusive upper limit (< condition)
            -- For DESC: prefix is the inclusive lower limit (>= condition)
            FOR v_current IN EXECUTE v_batch_query USING _bucket_id, v_next_seek,
                CASE WHEN v_is_asc THEN COALESCE(v_upper_bound, v_prefix) ELSE v_prefix END, v_file_batch_size
            LOOP
                v_common_prefix := storage.get_common_prefix(v_current.name, v_prefix, delimiter_param);

                IF v_common_prefix IS NOT NULL THEN
                    -- Hit a folder: exit batch, let peek handle it
                    v_next_seek := v_current.name;
                    EXIT;
                END IF;

                -- Emit file
                name := v_current.name;
                id := v_current.id;
                updated_at := v_current.updated_at;
                created_at := v_current.created_at;
                last_accessed_at := v_current.last_accessed_at;
                metadata := v_current.metadata;
                RETURN NEXT;
                v_count := v_count + 1;

                -- Advance seek past this file
                IF v_is_asc THEN
                    v_next_seek := v_current.name || delimiter_param;
                ELSE
                    v_next_seek := v_current.name;
                END IF;

                EXIT WHEN v_count >= max_keys;
            END LOOP;
        END IF;
    END LOOP;
END;
$_$;


ALTER FUNCTION "storage"."list_objects_with_delimiter"("_bucket_id" "text", "prefix_param" "text", "delimiter_param" "text", "max_keys" integer, "start_after" "text", "next_token" "text", "sort_order" "text") OWNER TO "supabase_storage_admin";


CREATE OR REPLACE FUNCTION "storage"."operation"() RETURNS "text"
    LANGUAGE "plpgsql" STABLE
    AS $$
BEGIN
    RETURN current_setting('storage.operation', true);
END;
$$;


ALTER FUNCTION "storage"."operation"() OWNER TO "supabase_storage_admin";


CREATE OR REPLACE FUNCTION "storage"."protect_delete"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    -- Check if storage.allow_delete_query is set to 'true'
    IF COALESCE(current_setting('storage.allow_delete_query', true), 'false') != 'true' THEN
        RAISE EXCEPTION 'Direct deletion from storage tables is not allowed. Use the Storage API instead.'
            USING HINT = 'This prevents accidental data loss from orphaned objects.',
                  ERRCODE = '42501';
    END IF;
    RETURN NULL;
END;
$$;


ALTER FUNCTION "storage"."protect_delete"() OWNER TO "supabase_storage_admin";


CREATE OR REPLACE FUNCTION "storage"."search"("prefix" "text", "bucketname" "text", "limits" integer DEFAULT 100, "levels" integer DEFAULT 1, "offsets" integer DEFAULT 0, "search" "text" DEFAULT ''::"text", "sortcolumn" "text" DEFAULT 'name'::"text", "sortorder" "text" DEFAULT 'asc'::"text") RETURNS TABLE("name" "text", "id" "uuid", "updated_at" timestamp with time zone, "created_at" timestamp with time zone, "last_accessed_at" timestamp with time zone, "metadata" "jsonb")
    LANGUAGE "plpgsql" STABLE
    AS $_$
DECLARE
    v_peek_name TEXT;
    v_current RECORD;
    v_common_prefix TEXT;
    v_delimiter CONSTANT TEXT := '/';

    -- Configuration
    v_limit INT;
    v_prefix TEXT;
    v_prefix_lower TEXT;
    v_is_asc BOOLEAN;
    v_order_by TEXT;
    v_sort_order TEXT;
    v_upper_bound TEXT;
    v_file_batch_size INT;

    -- Dynamic SQL for batch query only
    v_batch_query TEXT;

    -- Seek state
    v_next_seek TEXT;
    v_count INT := 0;
    v_skipped INT := 0;
BEGIN
    -- ========================================================================
    -- INITIALIZATION
    -- ========================================================================
    v_limit := LEAST(coalesce(limits, 100), 1500);
    v_prefix := coalesce(prefix, '') || coalesce(search, '');
    v_prefix_lower := lower(v_prefix);
    v_is_asc := lower(coalesce(sortorder, 'asc')) = 'asc';
    v_file_batch_size := LEAST(GREATEST(v_limit * 2, 100), 1000);

    -- Validate sort column
    CASE lower(coalesce(sortcolumn, 'name'))
        WHEN 'name' THEN v_order_by := 'name';
        WHEN 'updated_at' THEN v_order_by := 'updated_at';
        WHEN 'created_at' THEN v_order_by := 'created_at';
        WHEN 'last_accessed_at' THEN v_order_by := 'last_accessed_at';
        ELSE v_order_by := 'name';
    END CASE;

    v_sort_order := CASE WHEN v_is_asc THEN 'asc' ELSE 'desc' END;

    -- ========================================================================
    -- NON-NAME SORTING: Use path_tokens approach (unchanged)
    -- ========================================================================
    IF v_order_by != 'name' THEN
        RETURN QUERY EXECUTE format(
            $sql$
            WITH folders AS (
                SELECT path_tokens[$1] AS folder
                FROM storage.objects
                WHERE objects.name ILIKE $2 || '%%'
                  AND bucket_id = $3
                  AND array_length(objects.path_tokens, 1) <> $1
                GROUP BY folder
                ORDER BY folder %s
            )
            (SELECT folder AS "name",
                   NULL::uuid AS id,
                   NULL::timestamptz AS updated_at,
                   NULL::timestamptz AS created_at,
                   NULL::timestamptz AS last_accessed_at,
                   NULL::jsonb AS metadata FROM folders)
            UNION ALL
            (SELECT path_tokens[$1] AS "name",
                   id, updated_at, created_at, last_accessed_at, metadata
             FROM storage.objects
             WHERE objects.name ILIKE $2 || '%%'
               AND bucket_id = $3
               AND array_length(objects.path_tokens, 1) = $1
             ORDER BY %I %s)
            LIMIT $4 OFFSET $5
            $sql$, v_sort_order, v_order_by, v_sort_order
        ) USING levels, v_prefix, bucketname, v_limit, offsets;
        RETURN;
    END IF;

    -- ========================================================================
    -- NAME SORTING: Hybrid skip-scan with batch optimization
    -- ========================================================================

    -- Calculate upper bound for prefix filtering
    IF v_prefix_lower = '' THEN
        v_upper_bound := NULL;
    ELSIF right(v_prefix_lower, 1) = v_delimiter THEN
        v_upper_bound := left(v_prefix_lower, -1) || chr(ascii(v_delimiter) + 1);
    ELSE
        v_upper_bound := left(v_prefix_lower, -1) || chr(ascii(right(v_prefix_lower, 1)) + 1);
    END IF;

    -- Build batch query (dynamic SQL - called infrequently, amortized over many rows)
    IF v_is_asc THEN
        IF v_upper_bound IS NOT NULL THEN
            v_batch_query := 'SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata ' ||
                'FROM storage.objects o WHERE o.bucket_id = $1 AND lower(o.name) COLLATE "C" >= $2 ' ||
                'AND lower(o.name) COLLATE "C" < $3 ORDER BY lower(o.name) COLLATE "C" ASC LIMIT $4';
        ELSE
            v_batch_query := 'SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata ' ||
                'FROM storage.objects o WHERE o.bucket_id = $1 AND lower(o.name) COLLATE "C" >= $2 ' ||
                'ORDER BY lower(o.name) COLLATE "C" ASC LIMIT $4';
        END IF;
    ELSE
        IF v_upper_bound IS NOT NULL THEN
            v_batch_query := 'SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata ' ||
                'FROM storage.objects o WHERE o.bucket_id = $1 AND lower(o.name) COLLATE "C" < $2 ' ||
                'AND lower(o.name) COLLATE "C" >= $3 ORDER BY lower(o.name) COLLATE "C" DESC LIMIT $4';
        ELSE
            v_batch_query := 'SELECT o.name, o.id, o.updated_at, o.created_at, o.last_accessed_at, o.metadata ' ||
                'FROM storage.objects o WHERE o.bucket_id = $1 AND lower(o.name) COLLATE "C" < $2 ' ||
                'ORDER BY lower(o.name) COLLATE "C" DESC LIMIT $4';
        END IF;
    END IF;

    -- Initialize seek position
    IF v_is_asc THEN
        v_next_seek := v_prefix_lower;
    ELSE
        -- DESC: find the last item in range first (static SQL)
        IF v_upper_bound IS NOT NULL THEN
            SELECT o.name INTO v_peek_name FROM storage.objects o
            WHERE o.bucket_id = bucketname AND lower(o.name) COLLATE "C" >= v_prefix_lower AND lower(o.name) COLLATE "C" < v_upper_bound
            ORDER BY lower(o.name) COLLATE "C" DESC LIMIT 1;
        ELSIF v_prefix_lower <> '' THEN
            SELECT o.name INTO v_peek_name FROM storage.objects o
            WHERE o.bucket_id = bucketname AND lower(o.name) COLLATE "C" >= v_prefix_lower
            ORDER BY lower(o.name) COLLATE "C" DESC LIMIT 1;
        ELSE
            SELECT o.name INTO v_peek_name FROM storage.objects o
            WHERE o.bucket_id = bucketname
            ORDER BY lower(o.name) COLLATE "C" DESC LIMIT 1;
        END IF;

        IF v_peek_name IS NOT NULL THEN
            v_next_seek := lower(v_peek_name) || v_delimiter;
        ELSE
            RETURN;
        END IF;
    END IF;

    -- ========================================================================
    -- MAIN LOOP: Hybrid peek-then-batch algorithm
    -- Uses STATIC SQL for peek (hot path) and DYNAMIC SQL for batch
    -- ========================================================================
    LOOP
        EXIT WHEN v_count >= v_limit;

        -- STEP 1: PEEK using STATIC SQL (plan cached, very fast)
        IF v_is_asc THEN
            IF v_upper_bound IS NOT NULL THEN
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = bucketname AND lower(o.name) COLLATE "C" >= v_next_seek AND lower(o.name) COLLATE "C" < v_upper_bound
                ORDER BY lower(o.name) COLLATE "C" ASC LIMIT 1;
            ELSE
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = bucketname AND lower(o.name) COLLATE "C" >= v_next_seek
                ORDER BY lower(o.name) COLLATE "C" ASC LIMIT 1;
            END IF;
        ELSE
            IF v_upper_bound IS NOT NULL THEN
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = bucketname AND lower(o.name) COLLATE "C" < v_next_seek AND lower(o.name) COLLATE "C" >= v_prefix_lower
                ORDER BY lower(o.name) COLLATE "C" DESC LIMIT 1;
            ELSIF v_prefix_lower <> '' THEN
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = bucketname AND lower(o.name) COLLATE "C" < v_next_seek AND lower(o.name) COLLATE "C" >= v_prefix_lower
                ORDER BY lower(o.name) COLLATE "C" DESC LIMIT 1;
            ELSE
                SELECT o.name INTO v_peek_name FROM storage.objects o
                WHERE o.bucket_id = bucketname AND lower(o.name) COLLATE "C" < v_next_seek
                ORDER BY lower(o.name) COLLATE "C" DESC LIMIT 1;
            END IF;
        END IF;

        EXIT WHEN v_peek_name IS NULL;

        -- STEP 2: Check if this is a FOLDER or FILE
        v_common_prefix := storage.get_common_prefix(lower(v_peek_name), v_prefix_lower, v_delimiter);

        IF v_common_prefix IS NOT NULL THEN
            -- FOLDER: Handle offset, emit if needed, skip to next folder
            IF v_skipped < offsets THEN
                v_skipped := v_skipped + 1;
            ELSE
                name := split_part(rtrim(storage.get_common_prefix(v_peek_name, v_prefix, v_delimiter), v_delimiter), v_delimiter, levels);
                id := NULL;
                updated_at := NULL;
                created_at := NULL;
                last_accessed_at := NULL;
                metadata := NULL;
                RETURN NEXT;
                v_count := v_count + 1;
            END IF;

            -- Advance seek past the folder range
            IF v_is_asc THEN
                v_next_seek := lower(left(v_common_prefix, -1)) || chr(ascii(v_delimiter) + 1);
            ELSE
                v_next_seek := lower(v_common_prefix);
            END IF;
        ELSE
            -- FILE: Batch fetch using DYNAMIC SQL (overhead amortized over many rows)
            -- For ASC: upper_bound is the exclusive upper limit (< condition)
            -- For DESC: prefix_lower is the inclusive lower limit (>= condition)
            FOR v_current IN EXECUTE v_batch_query
                USING bucketname, v_next_seek,
                    CASE WHEN v_is_asc THEN COALESCE(v_upper_bound, v_prefix_lower) ELSE v_prefix_lower END, v_file_batch_size
            LOOP
                v_common_prefix := storage.get_common_prefix(lower(v_current.name), v_prefix_lower, v_delimiter);

                IF v_common_prefix IS NOT NULL THEN
                    -- Hit a folder: exit batch, let peek handle it
                    v_next_seek := lower(v_current.name);
                    EXIT;
                END IF;

                -- Handle offset skipping
                IF v_skipped < offsets THEN
                    v_skipped := v_skipped + 1;
                ELSE
                    -- Emit file
                    name := split_part(v_current.name, v_delimiter, levels);
                    id := v_current.id;
                    updated_at := v_current.updated_at;
                    created_at := v_current.created_at;
                    last_accessed_at := v_current.last_accessed_at;
                    metadata := v_current.metadata;
                    RETURN NEXT;
                    v_count := v_count + 1;
                END IF;

                -- Advance seek past this file
                IF v_is_asc THEN
                    v_next_seek := lower(v_current.name) || v_delimiter;
                ELSE
                    v_next_seek := lower(v_current.name);
                END IF;

                EXIT WHEN v_count >= v_limit;
            END LOOP;
        END IF;
    END LOOP;
END;
$_$;


ALTER FUNCTION "storage"."search"("prefix" "text", "bucketname" "text", "limits" integer, "levels" integer, "offsets" integer, "search" "text", "sortcolumn" "text", "sortorder" "text") OWNER TO "supabase_storage_admin";


CREATE OR REPLACE FUNCTION "storage"."search_by_timestamp"("p_prefix" "text", "p_bucket_id" "text", "p_limit" integer, "p_level" integer, "p_start_after" "text", "p_sort_order" "text", "p_sort_column" "text", "p_sort_column_after" "text") RETURNS TABLE("key" "text", "name" "text", "id" "uuid", "updated_at" timestamp with time zone, "created_at" timestamp with time zone, "last_accessed_at" timestamp with time zone, "metadata" "jsonb")
    LANGUAGE "plpgsql" STABLE
    AS $_$
DECLARE
    v_cursor_op text;
    v_query text;
    v_prefix text;
BEGIN
    v_prefix := coalesce(p_prefix, '');

    IF p_sort_order = 'asc' THEN
        v_cursor_op := '>';
    ELSE
        v_cursor_op := '<';
    END IF;

    v_query := format($sql$
        WITH raw_objects AS (
            SELECT
                o.name AS obj_name,
                o.id AS obj_id,
                o.updated_at AS obj_updated_at,
                o.created_at AS obj_created_at,
                o.last_accessed_at AS obj_last_accessed_at,
                o.metadata AS obj_metadata,
                storage.get_common_prefix(o.name, $1, '/') AS common_prefix
            FROM storage.objects o
            WHERE o.bucket_id = $2
              AND o.name COLLATE "C" LIKE $1 || '%%'
        ),
        -- Aggregate common prefixes (folders)
        -- Both created_at and updated_at use MIN(obj_created_at) to match the old prefixes table behavior
        aggregated_prefixes AS (
            SELECT
                rtrim(common_prefix, '/') AS name,
                NULL::uuid AS id,
                MIN(obj_created_at) AS updated_at,
                MIN(obj_created_at) AS created_at,
                NULL::timestamptz AS last_accessed_at,
                NULL::jsonb AS metadata,
                TRUE AS is_prefix
            FROM raw_objects
            WHERE common_prefix IS NOT NULL
            GROUP BY common_prefix
        ),
        leaf_objects AS (
            SELECT
                obj_name AS name,
                obj_id AS id,
                obj_updated_at AS updated_at,
                obj_created_at AS created_at,
                obj_last_accessed_at AS last_accessed_at,
                obj_metadata AS metadata,
                FALSE AS is_prefix
            FROM raw_objects
            WHERE common_prefix IS NULL
        ),
        combined AS (
            SELECT * FROM aggregated_prefixes
            UNION ALL
            SELECT * FROM leaf_objects
        ),
        filtered AS (
            SELECT *
            FROM combined
            WHERE (
                $5 = ''
                OR ROW(
                    date_trunc('milliseconds', %I),
                    name COLLATE "C"
                ) %s ROW(
                    COALESCE(NULLIF($6, '')::timestamptz, 'epoch'::timestamptz),
                    $5
                )
            )
        )
        SELECT
            split_part(name, '/', $3) AS key,
            name,
            id,
            updated_at,
            created_at,
            last_accessed_at,
            metadata
        FROM filtered
        ORDER BY
            COALESCE(date_trunc('milliseconds', %I), 'epoch'::timestamptz) %s,
            name COLLATE "C" %s
        LIMIT $4
    $sql$,
        p_sort_column,
        v_cursor_op,
        p_sort_column,
        p_sort_order,
        p_sort_order
    );

    RETURN QUERY EXECUTE v_query
    USING v_prefix, p_bucket_id, p_level, p_limit, p_start_after, p_sort_column_after;
END;
$_$;


ALTER FUNCTION "storage"."search_by_timestamp"("p_prefix" "text", "p_bucket_id" "text", "p_limit" integer, "p_level" integer, "p_start_after" "text", "p_sort_order" "text", "p_sort_column" "text", "p_sort_column_after" "text") OWNER TO "supabase_storage_admin";


CREATE OR REPLACE FUNCTION "storage"."search_legacy_v1"("prefix" "text", "bucketname" "text", "limits" integer DEFAULT 100, "levels" integer DEFAULT 1, "offsets" integer DEFAULT 0, "search" "text" DEFAULT ''::"text", "sortcolumn" "text" DEFAULT 'name'::"text", "sortorder" "text" DEFAULT 'asc'::"text") RETURNS TABLE("name" "text", "id" "uuid", "updated_at" timestamp with time zone, "created_at" timestamp with time zone, "last_accessed_at" timestamp with time zone, "metadata" "jsonb")
    LANGUAGE "plpgsql" STABLE
    AS $_$
declare
    v_order_by text;
    v_sort_order text;
begin
    case
        when sortcolumn = 'name' then
            v_order_by = 'name';
        when sortcolumn = 'updated_at' then
            v_order_by = 'updated_at';
        when sortcolumn = 'created_at' then
            v_order_by = 'created_at';
        when sortcolumn = 'last_accessed_at' then
            v_order_by = 'last_accessed_at';
        else
            v_order_by = 'name';
        end case;

    case
        when sortorder = 'asc' then
            v_sort_order = 'asc';
        when sortorder = 'desc' then
            v_sort_order = 'desc';
        else
            v_sort_order = 'asc';
        end case;

    v_order_by = v_order_by || ' ' || v_sort_order;

    return query execute
        'with folders as (
           select path_tokens[$1] as folder
           from storage.objects
             where objects.name ilike $2 || $3 || ''%''
               and bucket_id = $4
               and array_length(objects.path_tokens, 1) <> $1
           group by folder
           order by folder ' || v_sort_order || '
     )
     (select folder as "name",
            null as id,
            null as updated_at,
            null as created_at,
            null as last_accessed_at,
            null as metadata from folders)
     union all
     (select path_tokens[$1] as "name",
            id,
            updated_at,
            created_at,
            last_accessed_at,
            metadata
     from storage.objects
     where objects.name ilike $2 || $3 || ''%''
       and bucket_id = $4
       and array_length(objects.path_tokens, 1) = $1
     order by ' || v_order_by || ')
     limit $5
     offset $6' using levels, prefix, search, bucketname, limits, offsets;
end;
$_$;


ALTER FUNCTION "storage"."search_legacy_v1"("prefix" "text", "bucketname" "text", "limits" integer, "levels" integer, "offsets" integer, "search" "text", "sortcolumn" "text", "sortorder" "text") OWNER TO "supabase_storage_admin";


CREATE OR REPLACE FUNCTION "storage"."search_v2"("prefix" "text", "bucket_name" "text", "limits" integer DEFAULT 100, "levels" integer DEFAULT 1, "start_after" "text" DEFAULT ''::"text", "sort_order" "text" DEFAULT 'asc'::"text", "sort_column" "text" DEFAULT 'name'::"text", "sort_column_after" "text" DEFAULT ''::"text") RETURNS TABLE("key" "text", "name" "text", "id" "uuid", "updated_at" timestamp with time zone, "created_at" timestamp with time zone, "last_accessed_at" timestamp with time zone, "metadata" "jsonb")
    LANGUAGE "plpgsql" STABLE
    AS $$
DECLARE
    v_sort_col text;
    v_sort_ord text;
    v_limit int;
BEGIN
    -- Cap limit to maximum of 1500 records
    v_limit := LEAST(coalesce(limits, 100), 1500);

    -- Validate and normalize sort_order
    v_sort_ord := lower(coalesce(sort_order, 'asc'));
    IF v_sort_ord NOT IN ('asc', 'desc') THEN
        v_sort_ord := 'asc';
    END IF;

    -- Validate and normalize sort_column
    v_sort_col := lower(coalesce(sort_column, 'name'));
    IF v_sort_col NOT IN ('name', 'updated_at', 'created_at') THEN
        v_sort_col := 'name';
    END IF;

    -- Route to appropriate implementation
    IF v_sort_col = 'name' THEN
        -- Use list_objects_with_delimiter for name sorting (most efficient: O(k * log n))
        RETURN QUERY
        SELECT
            split_part(l.name, '/', levels) AS key,
            l.name AS name,
            l.id,
            l.updated_at,
            l.created_at,
            l.last_accessed_at,
            l.metadata
        FROM storage.list_objects_with_delimiter(
            bucket_name,
            coalesce(prefix, ''),
            '/',
            v_limit,
            start_after,
            '',
            v_sort_ord
        ) l;
    ELSE
        -- Use aggregation approach for timestamp sorting
        -- Not efficient for large datasets but supports correct pagination
        RETURN QUERY SELECT * FROM storage.search_by_timestamp(
            prefix, bucket_name, v_limit, levels, start_after,
            v_sort_ord, v_sort_col, sort_column_after
        );
    END IF;
END;
$$;


ALTER FUNCTION "storage"."search_v2"("prefix" "text", "bucket_name" "text", "limits" integer, "levels" integer, "start_after" "text", "sort_order" "text", "sort_column" "text", "sort_column_after" "text") OWNER TO "supabase_storage_admin";


CREATE OR REPLACE FUNCTION "storage"."update_updated_at_column"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW; 
END;
$$;


ALTER FUNCTION "storage"."update_updated_at_column"() OWNER TO "supabase_storage_admin";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "auth"."audit_log_entries" (
    "instance_id" "uuid",
    "id" "uuid" NOT NULL,
    "payload" json,
    "created_at" timestamp with time zone,
    "ip_address" character varying(64) DEFAULT ''::character varying NOT NULL
);


ALTER TABLE "auth"."audit_log_entries" OWNER TO "supabase_auth_admin";


COMMENT ON TABLE "auth"."audit_log_entries" IS 'Auth: Audit trail for user actions.';



CREATE TABLE IF NOT EXISTS "auth"."flow_state" (
    "id" "uuid" NOT NULL,
    "user_id" "uuid",
    "auth_code" "text" NOT NULL,
    "code_challenge_method" "auth"."code_challenge_method" NOT NULL,
    "code_challenge" "text" NOT NULL,
    "provider_type" "text" NOT NULL,
    "provider_access_token" "text",
    "provider_refresh_token" "text",
    "created_at" timestamp with time zone,
    "updated_at" timestamp with time zone,
    "authentication_method" "text" NOT NULL,
    "auth_code_issued_at" timestamp with time zone
);


ALTER TABLE "auth"."flow_state" OWNER TO "supabase_auth_admin";


COMMENT ON TABLE "auth"."flow_state" IS 'stores metadata for pkce logins';



CREATE TABLE IF NOT EXISTS "auth"."identities" (
    "provider_id" "text" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "identity_data" "jsonb" NOT NULL,
    "provider" "text" NOT NULL,
    "last_sign_in_at" timestamp with time zone,
    "created_at" timestamp with time zone,
    "updated_at" timestamp with time zone,
    "email" "text" GENERATED ALWAYS AS ("lower"(("identity_data" ->> 'email'::"text"))) STORED,
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL
);


ALTER TABLE "auth"."identities" OWNER TO "supabase_auth_admin";


COMMENT ON TABLE "auth"."identities" IS 'Auth: Stores identities associated to a user.';



COMMENT ON COLUMN "auth"."identities"."email" IS 'Auth: Email is a generated column that references the optional email property in the identity_data';



CREATE TABLE IF NOT EXISTS "auth"."instances" (
    "id" "uuid" NOT NULL,
    "uuid" "uuid",
    "raw_base_config" "text",
    "created_at" timestamp with time zone,
    "updated_at" timestamp with time zone
);


ALTER TABLE "auth"."instances" OWNER TO "supabase_auth_admin";


COMMENT ON TABLE "auth"."instances" IS 'Auth: Manages users across multiple sites.';



CREATE TABLE IF NOT EXISTS "auth"."mfa_amr_claims" (
    "session_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone NOT NULL,
    "updated_at" timestamp with time zone NOT NULL,
    "authentication_method" "text" NOT NULL,
    "id" "uuid" NOT NULL
);


ALTER TABLE "auth"."mfa_amr_claims" OWNER TO "supabase_auth_admin";


COMMENT ON TABLE "auth"."mfa_amr_claims" IS 'auth: stores authenticator method reference claims for multi factor authentication';



CREATE TABLE IF NOT EXISTS "auth"."mfa_challenges" (
    "id" "uuid" NOT NULL,
    "factor_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone NOT NULL,
    "verified_at" timestamp with time zone,
    "ip_address" "inet" NOT NULL,
    "otp_code" "text",
    "web_authn_session_data" "jsonb"
);


ALTER TABLE "auth"."mfa_challenges" OWNER TO "supabase_auth_admin";


COMMENT ON TABLE "auth"."mfa_challenges" IS 'auth: stores metadata about challenge requests made';



CREATE TABLE IF NOT EXISTS "auth"."mfa_factors" (
    "id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "friendly_name" "text",
    "factor_type" "auth"."factor_type" NOT NULL,
    "status" "auth"."factor_status" NOT NULL,
    "created_at" timestamp with time zone NOT NULL,
    "updated_at" timestamp with time zone NOT NULL,
    "secret" "text",
    "phone" "text",
    "last_challenged_at" timestamp with time zone,
    "web_authn_credential" "jsonb",
    "web_authn_aaguid" "uuid",
    "last_webauthn_challenge_data" "jsonb"
);


ALTER TABLE "auth"."mfa_factors" OWNER TO "supabase_auth_admin";


COMMENT ON TABLE "auth"."mfa_factors" IS 'auth: stores metadata about factors';



COMMENT ON COLUMN "auth"."mfa_factors"."last_webauthn_challenge_data" IS 'Stores the latest WebAuthn challenge data including attestation/assertion for customer verification';



CREATE TABLE IF NOT EXISTS "auth"."oauth_authorizations" (
    "id" "uuid" NOT NULL,
    "authorization_id" "text" NOT NULL,
    "client_id" "uuid" NOT NULL,
    "user_id" "uuid",
    "redirect_uri" "text" NOT NULL,
    "scope" "text" NOT NULL,
    "state" "text",
    "resource" "text",
    "code_challenge" "text",
    "code_challenge_method" "auth"."code_challenge_method",
    "response_type" "auth"."oauth_response_type" DEFAULT 'code'::"auth"."oauth_response_type" NOT NULL,
    "status" "auth"."oauth_authorization_status" DEFAULT 'pending'::"auth"."oauth_authorization_status" NOT NULL,
    "authorization_code" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "expires_at" timestamp with time zone DEFAULT ("now"() + '00:03:00'::interval) NOT NULL,
    "approved_at" timestamp with time zone,
    "nonce" "text",
    CONSTRAINT "oauth_authorizations_authorization_code_length" CHECK (("char_length"("authorization_code") <= 255)),
    CONSTRAINT "oauth_authorizations_code_challenge_length" CHECK (("char_length"("code_challenge") <= 128)),
    CONSTRAINT "oauth_authorizations_expires_at_future" CHECK (("expires_at" > "created_at")),
    CONSTRAINT "oauth_authorizations_nonce_length" CHECK (("char_length"("nonce") <= 255)),
    CONSTRAINT "oauth_authorizations_redirect_uri_length" CHECK (("char_length"("redirect_uri") <= 2048)),
    CONSTRAINT "oauth_authorizations_resource_length" CHECK (("char_length"("resource") <= 2048)),
    CONSTRAINT "oauth_authorizations_scope_length" CHECK (("char_length"("scope") <= 4096)),
    CONSTRAINT "oauth_authorizations_state_length" CHECK (("char_length"("state") <= 4096))
);


ALTER TABLE "auth"."oauth_authorizations" OWNER TO "supabase_auth_admin";


CREATE TABLE IF NOT EXISTS "auth"."oauth_client_states" (
    "id" "uuid" NOT NULL,
    "provider_type" "text" NOT NULL,
    "code_verifier" "text",
    "created_at" timestamp with time zone NOT NULL
);


ALTER TABLE "auth"."oauth_client_states" OWNER TO "supabase_auth_admin";


COMMENT ON TABLE "auth"."oauth_client_states" IS 'Stores OAuth states for third-party provider authentication flows where Supabase acts as the OAuth client.';



CREATE TABLE IF NOT EXISTS "auth"."oauth_clients" (
    "id" "uuid" NOT NULL,
    "client_secret_hash" "text",
    "registration_type" "auth"."oauth_registration_type" NOT NULL,
    "redirect_uris" "text" NOT NULL,
    "grant_types" "text" NOT NULL,
    "client_name" "text",
    "client_uri" "text",
    "logo_uri" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "deleted_at" timestamp with time zone,
    "client_type" "auth"."oauth_client_type" DEFAULT 'confidential'::"auth"."oauth_client_type" NOT NULL,
    CONSTRAINT "oauth_clients_client_name_length" CHECK (("char_length"("client_name") <= 1024)),
    CONSTRAINT "oauth_clients_client_uri_length" CHECK (("char_length"("client_uri") <= 2048)),
    CONSTRAINT "oauth_clients_logo_uri_length" CHECK (("char_length"("logo_uri") <= 2048))
);


ALTER TABLE "auth"."oauth_clients" OWNER TO "supabase_auth_admin";


CREATE TABLE IF NOT EXISTS "auth"."oauth_consents" (
    "id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "client_id" "uuid" NOT NULL,
    "scopes" "text" NOT NULL,
    "granted_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "revoked_at" timestamp with time zone,
    CONSTRAINT "oauth_consents_revoked_after_granted" CHECK ((("revoked_at" IS NULL) OR ("revoked_at" >= "granted_at"))),
    CONSTRAINT "oauth_consents_scopes_length" CHECK (("char_length"("scopes") <= 2048)),
    CONSTRAINT "oauth_consents_scopes_not_empty" CHECK (("char_length"(TRIM(BOTH FROM "scopes")) > 0))
);


ALTER TABLE "auth"."oauth_consents" OWNER TO "supabase_auth_admin";


CREATE TABLE IF NOT EXISTS "auth"."one_time_tokens" (
    "id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "token_type" "auth"."one_time_token_type" NOT NULL,
    "token_hash" "text" NOT NULL,
    "relates_to" "text" NOT NULL,
    "created_at" timestamp without time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp without time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "one_time_tokens_token_hash_check" CHECK (("char_length"("token_hash") > 0))
);


ALTER TABLE "auth"."one_time_tokens" OWNER TO "supabase_auth_admin";


CREATE TABLE IF NOT EXISTS "auth"."refresh_tokens" (
    "instance_id" "uuid",
    "id" bigint NOT NULL,
    "token" character varying(255),
    "user_id" character varying(255),
    "revoked" boolean,
    "created_at" timestamp with time zone,
    "updated_at" timestamp with time zone,
    "parent" character varying(255),
    "session_id" "uuid"
);


ALTER TABLE "auth"."refresh_tokens" OWNER TO "supabase_auth_admin";


COMMENT ON TABLE "auth"."refresh_tokens" IS 'Auth: Store of tokens used to refresh JWT tokens once they expire.';



CREATE SEQUENCE IF NOT EXISTS "auth"."refresh_tokens_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "auth"."refresh_tokens_id_seq" OWNER TO "supabase_auth_admin";


ALTER SEQUENCE "auth"."refresh_tokens_id_seq" OWNED BY "auth"."refresh_tokens"."id";



CREATE TABLE IF NOT EXISTS "auth"."saml_providers" (
    "id" "uuid" NOT NULL,
    "sso_provider_id" "uuid" NOT NULL,
    "entity_id" "text" NOT NULL,
    "metadata_xml" "text" NOT NULL,
    "metadata_url" "text",
    "attribute_mapping" "jsonb",
    "created_at" timestamp with time zone,
    "updated_at" timestamp with time zone,
    "name_id_format" "text",
    CONSTRAINT "entity_id not empty" CHECK (("char_length"("entity_id") > 0)),
    CONSTRAINT "metadata_url not empty" CHECK ((("metadata_url" = NULL::"text") OR ("char_length"("metadata_url") > 0))),
    CONSTRAINT "metadata_xml not empty" CHECK (("char_length"("metadata_xml") > 0))
);


ALTER TABLE "auth"."saml_providers" OWNER TO "supabase_auth_admin";


COMMENT ON TABLE "auth"."saml_providers" IS 'Auth: Manages SAML Identity Provider connections.';



CREATE TABLE IF NOT EXISTS "auth"."saml_relay_states" (
    "id" "uuid" NOT NULL,
    "sso_provider_id" "uuid" NOT NULL,
    "request_id" "text" NOT NULL,
    "for_email" "text",
    "redirect_to" "text",
    "created_at" timestamp with time zone,
    "updated_at" timestamp with time zone,
    "flow_state_id" "uuid",
    CONSTRAINT "request_id not empty" CHECK (("char_length"("request_id") > 0))
);


ALTER TABLE "auth"."saml_relay_states" OWNER TO "supabase_auth_admin";


COMMENT ON TABLE "auth"."saml_relay_states" IS 'Auth: Contains SAML Relay State information for each Service Provider initiated login.';



CREATE TABLE IF NOT EXISTS "auth"."schema_migrations" (
    "version" character varying(255) NOT NULL
);


ALTER TABLE "auth"."schema_migrations" OWNER TO "supabase_auth_admin";


COMMENT ON TABLE "auth"."schema_migrations" IS 'Auth: Manages updates to the auth system.';



CREATE TABLE IF NOT EXISTS "auth"."sessions" (
    "id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone,
    "updated_at" timestamp with time zone,
    "factor_id" "uuid",
    "aal" "auth"."aal_level",
    "not_after" timestamp with time zone,
    "refreshed_at" timestamp without time zone,
    "user_agent" "text",
    "ip" "inet",
    "tag" "text",
    "oauth_client_id" "uuid",
    "refresh_token_hmac_key" "text",
    "refresh_token_counter" bigint,
    "scopes" "text",
    CONSTRAINT "sessions_scopes_length" CHECK (("char_length"("scopes") <= 4096))
);


ALTER TABLE "auth"."sessions" OWNER TO "supabase_auth_admin";


COMMENT ON TABLE "auth"."sessions" IS 'Auth: Stores session data associated to a user.';



COMMENT ON COLUMN "auth"."sessions"."not_after" IS 'Auth: Not after is a nullable column that contains a timestamp after which the session should be regarded as expired.';



COMMENT ON COLUMN "auth"."sessions"."refresh_token_hmac_key" IS 'Holds a HMAC-SHA256 key used to sign refresh tokens for this session.';



COMMENT ON COLUMN "auth"."sessions"."refresh_token_counter" IS 'Holds the ID (counter) of the last issued refresh token.';



CREATE TABLE IF NOT EXISTS "auth"."sso_domains" (
    "id" "uuid" NOT NULL,
    "sso_provider_id" "uuid" NOT NULL,
    "domain" "text" NOT NULL,
    "created_at" timestamp with time zone,
    "updated_at" timestamp with time zone,
    CONSTRAINT "domain not empty" CHECK (("char_length"("domain") > 0))
);


ALTER TABLE "auth"."sso_domains" OWNER TO "supabase_auth_admin";


COMMENT ON TABLE "auth"."sso_domains" IS 'Auth: Manages SSO email address domain mapping to an SSO Identity Provider.';



CREATE TABLE IF NOT EXISTS "auth"."sso_providers" (
    "id" "uuid" NOT NULL,
    "resource_id" "text",
    "created_at" timestamp with time zone,
    "updated_at" timestamp with time zone,
    "disabled" boolean,
    CONSTRAINT "resource_id not empty" CHECK ((("resource_id" = NULL::"text") OR ("char_length"("resource_id") > 0)))
);


ALTER TABLE "auth"."sso_providers" OWNER TO "supabase_auth_admin";


COMMENT ON TABLE "auth"."sso_providers" IS 'Auth: Manages SSO identity provider information; see saml_providers for SAML.';



COMMENT ON COLUMN "auth"."sso_providers"."resource_id" IS 'Auth: Uniquely identifies a SSO provider according to a user-chosen resource ID (case insensitive), useful in infrastructure as code.';



CREATE TABLE IF NOT EXISTS "auth"."users" (
    "instance_id" "uuid",
    "id" "uuid" NOT NULL,
    "aud" character varying(255),
    "role" character varying(255),
    "email" character varying(255),
    "encrypted_password" character varying(255),
    "email_confirmed_at" timestamp with time zone,
    "invited_at" timestamp with time zone,
    "confirmation_token" character varying(255),
    "confirmation_sent_at" timestamp with time zone,
    "recovery_token" character varying(255),
    "recovery_sent_at" timestamp with time zone,
    "email_change_token_new" character varying(255),
    "email_change" character varying(255),
    "email_change_sent_at" timestamp with time zone,
    "last_sign_in_at" timestamp with time zone,
    "raw_app_meta_data" "jsonb",
    "raw_user_meta_data" "jsonb",
    "is_super_admin" boolean,
    "created_at" timestamp with time zone,
    "updated_at" timestamp with time zone,
    "phone" "text" DEFAULT NULL::character varying,
    "phone_confirmed_at" timestamp with time zone,
    "phone_change" "text" DEFAULT ''::character varying,
    "phone_change_token" character varying(255) DEFAULT ''::character varying,
    "phone_change_sent_at" timestamp with time zone,
    "confirmed_at" timestamp with time zone GENERATED ALWAYS AS (LEAST("email_confirmed_at", "phone_confirmed_at")) STORED,
    "email_change_token_current" character varying(255) DEFAULT ''::character varying,
    "email_change_confirm_status" smallint DEFAULT 0,
    "banned_until" timestamp with time zone,
    "reauthentication_token" character varying(255) DEFAULT ''::character varying,
    "reauthentication_sent_at" timestamp with time zone,
    "is_sso_user" boolean DEFAULT false NOT NULL,
    "deleted_at" timestamp with time zone,
    "is_anonymous" boolean DEFAULT false NOT NULL,
    CONSTRAINT "users_email_change_confirm_status_check" CHECK ((("email_change_confirm_status" >= 0) AND ("email_change_confirm_status" <= 2)))
);


ALTER TABLE "auth"."users" OWNER TO "supabase_auth_admin";


COMMENT ON TABLE "auth"."users" IS 'Auth: Stores user login data within a secure schema.';



COMMENT ON COLUMN "auth"."users"."is_sso_user" IS 'Auth: Set this column to true when the account comes from SSO. These accounts can have duplicate emails.';



CREATE TABLE IF NOT EXISTS "public"."TCD_anidro_hidratado" (
    "Temp.Obs." "text",
    "0,77" "text",
    "0,7705" "text",
    "0,771" "text",
    "0,7715" "text",
    "0,772" "text",
    "0,7725" "text",
    "0,773" "text",
    "0,7735" "text",
    "0,774" "text",
    "0,7745" "text",
    "0,775" "text",
    "0,7755" "text",
    "0,776" "text",
    "0,7765" "text",
    "0,777" "text",
    "0,7775" "text",
    "0,778" "text",
    "0,7785" "text",
    "0,779" "text",
    "0,7795" "text",
    "0,78" "text",
    "0,7805" "text",
    "0,781" "text",
    "0,7815" "text",
    "0,782" "text",
    "0,7825" "text",
    "0,783" "text",
    "0,7835" "text",
    "0,784" "text",
    "0,7845" "text",
    "0,785" "text",
    "0,786" "text",
    "0,787" "text",
    "0,788" "text",
    "0,789" "text",
    "0,79" "text",
    "0,791" "text",
    "0,792" "text",
    "0,793" "text",
    "0,794" "text",
    "0,795" "text",
    "0,796" "text",
    "0,797" "text",
    "0,798" "text",
    "0,799" "text",
    "0,8" "text",
    "0,801" "text",
    "0,802" "text",
    "0,803" "text",
    "0,804" "text",
    "0,805" "text",
    "0,806" "text",
    "0,807" "text",
    "0,808" "text",
    "0,809" "text",
    "0,81" "text",
    "0,811" "text",
    "0,812" "text",
    "0,813" "text",
    "0,814" "text",
    "0,815" "text",
    "0,816" "text",
    "0,817" "text",
    "0,818" "text",
    "0,819" "text"
);


ALTER TABLE "public"."TCD_anidro_hidratado" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."TCD_gasolina_diesel" (
    "Temp.Obs." "text",
    "0,6990" "text",
    "0,7000" "text",
    "0,7010" "text",
    "0,7020" "text",
    "0,7030" "text",
    "0,7040" "text",
    "0,7050" "text",
    "0,7060" "text",
    "0,7070" "text",
    "0,7080" "text",
    "0,7090" "text",
    "0,7100" "text",
    "0,7110" "text",
    "0,7120" "text",
    "0,7130" "text",
    "0,7140" "text",
    "0,7150" "text",
    "0,7160" "text",
    "0,7170" "text",
    "0,7180" "text",
    "0,7190" "text",
    "0,7200" "text",
    "0,7210" "text",
    "0,7220" "text",
    "0,7230" "text",
    "0,7240" "text",
    "0,7250" "text",
    "0,7260" "text",
    "0,7270" "text",
    "0,7280" "text",
    "0,7290" "text",
    "0,7300" "text",
    "0,7310" "text",
    "0,7320" "text",
    "0,7330" "text",
    "0,7340" "text",
    "0,7350" "text",
    "0,7360" "text",
    "0,7370" "text",
    "0,7380" "text",
    "0,7390" "text",
    "0,7400" "text",
    "0,7410" "text",
    "0,7420" "text",
    "0,7430" "text",
    "0,7440" "text",
    "0,7450" "text",
    "0,7460" "text",
    "0,7470" "text",
    "0,7480" "text",
    "0,7490" "text",
    "0,7500" "text",
    "0,7510" "text",
    "0,7520" "text",
    "0,7530" "text",
    "0,7540" "text",
    "0,7550" "text",
    "0,7560" "text",
    "0,7570" "text",
    "0,7580" "text",
    "0,7590" "text",
    "0,7600" "text",
    "0,7610" "text",
    "0,7620" "text",
    "0,7630" "text",
    "0,7640" "text",
    "0,7650" "text",
    "0,7660" "text",
    "0,7670" "text",
    "0,7680" "text",
    "0,7690" "text",
    "0,7700" "text",
    "0,7710" "text",
    "0,7720" "text",
    "0,7730" "text",
    "0,7740" "text",
    "0,7750" "text",
    "0,7760" "text",
    "0,7770" "text",
    "0,7780" "text",
    "0,7790" "text",
    "0,7800" "text",
    "0,7810" "text",
    "0,7820" "text",
    "0,7830" "text",
    "0,7840" "text",
    "0,7850" "text",
    "0,7860" "text",
    "0,7870" "text",
    "0,7880" "text",
    "0,7890" "text",
    "0,7900" "text",
    "0,7910" "text",
    "0,7920" "text",
    "0,7930" "text",
    "0,7940" "text",
    "0,7950" "text",
    "0,7960" "text",
    "0,7970" "text",
    "0,7980" "text",
    "0,7990" "text",
    "0,8000" "text",
    "0,8010" "text",
    "0,8020" "text",
    "0,8030" "text",
    "0,8040" "text",
    "0,8050" "text",
    "0,8060" "text",
    "0,8070" "text",
    "0,8080" "text",
    "0,8090" "text",
    "0,8100" "text",
    "0,8110" "text",
    "0,8120" "text",
    "0,8130" "text",
    "0,8140" "text",
    "0,8150" "text",
    "0,8160" "text",
    "0,8170" "text",
    "0,8180" "text",
    "0,8190" "text",
    "0,8200" "text",
    "0,8210" "text",
    "0,8220" "text",
    "0,8230" "text",
    "0,8240" "text",
    "0,8250" "text",
    "0,8260" "text",
    "0,8270" "text",
    "0,8280" "text",
    "0,8290" "text",
    "0,8300" "text",
    "0,8310" "text",
    "0,8320" "text",
    "0,8330" "text",
    "0,8340" "text",
    "0,8350" "text",
    "0,8360" "text",
    "0,8370" "text",
    "0,8380" "text",
    "0,8390" "text",
    "0,8400" "text",
    "0,8410" "text",
    "0,8420" "text",
    "0,8430" "text",
    "0,8440" "text",
    "0,8450" "text",
    "0,8460" "text",
    "0,8470" "text",
    "0,8480" "text",
    "0,8490" "text",
    "0,8500" "text",
    "0,8510" "text",
    "0,8520" "text",
    "0,8530" "text",
    "0,8540" "text",
    "0,8550" "text",
    "0,8560" "text",
    "0,8570" "text",
    "0,8580" "text",
    "0,8590" "text",
    "0,8600" "text",
    "0,8610" "text",
    "0,8620" "text",
    "0,8630" "text",
    "0,864" "text",
    "0,865" "text",
    "0,866" "text",
    "0,867" "text",
    "0,868" "text",
    "0,869" "text",
    "0,870" "text",
    "0,871" "text",
    "0,872" "text",
    "0,873" "text",
    "0,874" "text",
    "0,875" "text",
    "0,876" "text",
    "0,877" "text",
    "0,878" "text",
    "0,879" "text",
    "0,880" "text",
    "0,881" "text",
    "0,882" "text",
    "0,883" "text",
    "0,884" "text",
    "0,885" "text",
    "0,886" "text",
    "0,887" "text",
    "0,888" "text",
    "0,889" "text",
    "0,890" "text",
    "0,891" "text",
    "0,892" "text",
    "0,893" "text",
    "0,894" "text",
    "0,895" "text",
    "0,896" "text",
    "0,897" "text",
    "0,898" "text",
    "0,899" "text",
    "0,9" "text",
    "0,901" "text",
    "0,902" "text",
    "0,903" "text",
    "0,904" "text",
    "0,905" "text",
    "0,906" "text",
    "0,907" "text",
    "0,908" "text",
    "0,909" "text"
);


ALTER TABLE "public"."TCD_gasolina_diesel" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."TCV_anidro_hidratado" (
    "Temp.Obs." "text",
    "0,7" "text",
    "0,7893" "text",
    "0,7985" "text",
    "0,8098" "text",
    "0,8125" "text",
    "0,8153" "text",
    "0,8208" "text",
    "0,8232" "text",
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL
);


ALTER TABLE "public"."TCV_anidro_hidratado" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."TCV_gasolina_diesel" (
    "Temp.Obs." "text",
    "0,7050" "text",
    "0,7060" "text",
    "0,7070" "text",
    "0,7080" "text",
    "0,7090" "text",
    "0,7100" "text",
    "0,7110" "text",
    "0,7120" "text",
    "0,7130" "text",
    "0,7140" "text",
    "0,7150" "text",
    "0,7160" "text",
    "0,7170" "text",
    "0,7180" "text",
    "0,7190" "text",
    "0,7200" "text",
    "0,7210" "text",
    "0,7220" "text",
    "0,7230" "text",
    "0,7240" "text",
    "0,7250" "text",
    "0,7260" "text",
    "0,7270" "text",
    "0,7280" "text",
    "0,7290" "text",
    "0,7300" "text",
    "0,7310" "text",
    "0,7320" "text",
    "0,7330" "text",
    "0,7340" "text",
    "0,7350" "text",
    "0,7360" "text",
    "0,7370" "text",
    "0,7380" "text",
    "0,7390" "text",
    "0,7400" "text",
    "0,7410" "text",
    "0,7420" "text",
    "0,7430" "text",
    "0,7440" "text",
    "0,7450" "text",
    "0,7460" "text",
    "0,7470" "text",
    "0,7480" "text",
    "0,7490" "text",
    "0,7500" "text",
    "0,7510" "text",
    "0,7520" "text",
    "0,7530" "text",
    "0,7540" "text",
    "0,7550" "text",
    "0,7560" "text",
    "0,7570" "text",
    "0,7580" "text",
    "0,7590" "text",
    "0,7600" "text",
    "0,7610" "text",
    "0,7620" "text",
    "0,7630" "text",
    "0,7640" "text",
    "0,7650" "text",
    "0,7660" "text",
    "0,7670" "text",
    "0,7680" "text",
    "0,7690" "text",
    "0,7700" "text",
    "0,7710" "text",
    "0,7720" "text",
    "0,7730" "text",
    "0,7740" "text",
    "0,7750" "text",
    "0,7760" "text",
    "0,7770" "text",
    "0,7780" "text",
    "0,7790" "text",
    "0,7800" "text",
    "0,7810" "text",
    "0,7820" "text",
    "0,7830" "text",
    "0,7840" "text",
    "0,7850" "text",
    "0,7860" "text",
    "0,7870" "text",
    "0,7880" "text",
    "0,7890" "text",
    "0,7900" "text",
    "0,7910" "text",
    "0,7920" "text",
    "0,7930" "text",
    "0,7940" "text",
    "0,7950" "text",
    "0,7960" "text",
    "0,7970" "text",
    "0,7980" "text",
    "0,7990" "text",
    "0,8000" "text",
    "0,8010" "text",
    "0,8020" "text",
    "0,8030" "text",
    "0,8040" "text",
    "0,8050" "text",
    "0,8060" "text",
    "0,8070" "text",
    "0,8080" "text",
    "0,8090" "text",
    "0,8100" "text",
    "0,8110" "text",
    "0,8120" "text",
    "0,8130" "text",
    "0,8140" "text",
    "0,8150" "text",
    "0,8160" "text",
    "0,8170" "text",
    "0,8180" "text",
    "0,8190" "text",
    "0,8200" "text",
    "0,8210" "text",
    "0,8220" "text",
    "0,8230" "text",
    "0,8240" "text",
    "0,8250" "text",
    "0,8260" "text",
    "0,8270" "text",
    "0,8280" "text",
    "0,8290" "text",
    "0,8300" "text",
    "0,8310" "text",
    "0,8320" "text",
    "0,8330" "text",
    "0,8340" "text",
    "0,8350" "text",
    "0,8360" "text",
    "0,8370" "text",
    "0,8380" "text",
    "0,8390" "text",
    "0,8400" "text",
    "0,8410" "text",
    "0,8420" "text",
    "0,8430" "text",
    "0,8440" "text",
    "0,8450" "text",
    "0,8460" "text",
    "0,8470" "text",
    "0,8480" "text",
    "0,8490" "text",
    "0,8500" "text",
    "0,8510" "text",
    "0,8520" "text",
    "0,8530" "text",
    "0,8540" "text",
    "0,8550" "text",
    "0,8560" "text",
    "0,8570" "text",
    "0,8580" "text",
    "0,8590" "text",
    "0,8600" "text",
    "0,8610" "text",
    "0,8620" "text",
    "0,8630" "text",
    "0,8640" "text",
    "0,8650" "text",
    "0,8660" "text",
    "0,8670" "text",
    "0,8680" "text",
    "0,8690" "text",
    "0,8700" "text",
    "0,8710" "text",
    "0,8720" "text",
    "0,8730" "text",
    "0,8740" "text",
    "0,8750" "text",
    "0,8760" "text",
    "0,8770" "text",
    "0,8780" "text"
);


ALTER TABLE "public"."TCV_gasolina_diesel" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."ajuda" (
    "usuario_id" "uuid",
    "texto" "text",
    "data_criacao" timestamp with time zone DEFAULT "now"(),
    "status" "text",
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL
);


ALTER TABLE "public"."ajuda" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."arqueacao_janauba" (
    "altura_cm_mm" numeric,
    "tq_01_cm" double precision,
    "tq_02_cm" double precision,
    "tq_03_cm" double precision,
    "tq_04_cm" double precision,
    "tq_05_cm" double precision,
    "tq_06_cm" double precision,
    "tq_01_mm" "text",
    "tq_02_mm" "text",
    "tq_03_mm" "text",
    "tq_04_mm" "text",
    "tq_05_mm" "text",
    "tq_06_mm" "text"
);


ALTER TABLE "public"."arqueacao_janauba" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."arqueacao_jequie" (
    "altura_cm_mm" numeric,
    "tq_01_cm" double precision,
    "tq_01_mm" "text",
    "tq_02_cm" double precision,
    "tq_02_mm" "text",
    "tq_03_cm" double precision,
    "tq_03_mm" "text",
    "tq_04_cm" double precision,
    "tq_04_mm" "text",
    "tq_05_cm" double precision,
    "tq_05_mm" "text",
    "tq_06_cm" double precision,
    "tq_06_mm" "text",
    "tq_07_cm" "text",
    "tq_07_mm" "text",
    "tq_08_cm" "text",
    "tq_08_mm" "text",
    "tq_09_cm" double precision,
    "tq_09_mm" "text"
);


ALTER TABLE "public"."arqueacao_jequie" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."cacl" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "data" "date" NOT NULL,
    "base" "text",
    "produto" "text" NOT NULL,
    "tanque_id" "uuid",
    "filial_id" "uuid",
    "horario_inicial" timestamp without time zone,
    "altura_total_liquido_inicial" "text",
    "altura_total_cm_inicial" "text",
    "altura_total_mm_inicial" "text",
    "volume_total_liquido_inicial" double precision,
    "altura_agua_inicial" "text",
    "volume_agua_inicial" double precision,
    "altura_produto_inicial" "text",
    "volume_produto_inicial" double precision,
    "temperatura_tanque_inicial" "text",
    "densidade_observada_inicial" "text",
    "temperatura_amostra_inicial" "text",
    "densidade_20_inicial" "text",
    "fator_correcao_inicial" "text",
    "volume_20_inicial" double precision,
    "massa_inicial" "text",
    "horario_final" timestamp without time zone,
    "altura_total_liquido_final" "text",
    "altura_total_cm_final" "text",
    "altura_total_mm_final" "text",
    "volume_total_liquido_final" double precision,
    "altura_agua_final" "text",
    "volume_agua_final" double precision,
    "altura_produto_final" "text",
    "volume_produto_final" double precision,
    "temperatura_tanque_final" "text",
    "densidade_observada_final" "text",
    "temperatura_amostra_final" "text",
    "densidade_20_final" "text",
    "fator_correcao_final" "text",
    "volume_20_final" double precision,
    "massa_final" "text",
    "volume_ambiente_inicial" double precision,
    "volume_ambiente_final" double precision,
    "entrada_saida_ambiente" double precision,
    "entrada_saida_20" double precision,
    "faturado_final" double precision,
    "diferenca_faturado" double precision,
    "porcentagem_diferenca" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "created_by" "uuid",
    "status" "text" DEFAULT 'emitido'::"text",
    "tipo" "text",
    "solicita_canc" boolean DEFAULT false,
    "numero_controle" "text"
);


ALTER TABLE "public"."cacl" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."cadastros_pendentes" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "nome" "text" NOT NULL,
    "email" "text" NOT NULL,
    "celular" "text",
    "funcao" "text",
    "id_filial" "uuid",
    "nivel" integer,
    "status" "text" DEFAULT 'pendente'::"text" NOT NULL,
    "criado_em" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()),
    "nome_apelido" "text",
    CONSTRAINT "cadastros_pendentes_nivel_check" CHECK (("nivel" = ANY (ARRAY[1, 2])))
);


ALTER TABLE "public"."cadastros_pendentes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."cards" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "nome" character varying(100) NOT NULL,
    "tipo" character varying(50) NOT NULL,
    "sessao_pai" character varying(50) NOT NULL,
    "ordem" integer DEFAULT 0,
    "ativo" boolean DEFAULT true,
    "created_at" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."cards" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."coletas_tanques" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "movimentacao_id" "uuid" NOT NULL,
    "produto_id" "uuid" NOT NULL,
    "tanque_numero" integer NOT NULL,
    "placas" "text"[] NOT NULL,
    "temperatura_amostra" numeric NOT NULL,
    "densidade_observada" numeric NOT NULL,
    "temperatura_ct" numeric NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "volume_amb" numeric,
    "volume_vinte" numeric
);


ALTER TABLE "public"."coletas_tanques" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."conjuntos" (
    "motorista" "text",
    "motorista_id" "uuid",
    "cavalo" "text",
    "cavalo_id" "uuid",
    "reboque_um" "text",
    "reboque_um_id" "uuid",
    "reboque_dois" "text",
    "reboque_dois_id" "uuid",
    "capac" bigint,
    "tanques" "text",
    "pbt" double precision,
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL
);


ALTER TABLE "public"."conjuntos" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."empresas" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "nome" "text" NOT NULL,
    "cnpj" "text",
    "nome_abrev" "text"
);


ALTER TABLE "public"."empresas" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."equipamentos" (
    "placa" "text",
    "afericao" "text",
    "cipp" "text",
    "civ" "text",
    "tacografo" "text",
    "aet_fed" "text",
    "aet_ba" "text",
    "aet_go" "text",
    "aet_al" "text",
    "aet_mg" "text",
    "tanques" integer[],
    "transportadora_id" "uuid",
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "renavam" "text"
);


ALTER TABLE "public"."equipamentos" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."filiais" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "nome" "text" NOT NULL,
    "cnpj" "text" NOT NULL,
    "cidade" "text" NOT NULL,
    "empresa_id" "uuid",
    "nome_dois" "text"
);


ALTER TABLE "public"."filiais" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."motoristas" (
    "nome" "text",
    "cpf" "text",
    "cnh" bigint,
    "categoria" "text",
    "telefone" "text",
    "telefone_2" "text",
    "nome_2" "text",
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "transportadora_id" "uuid",
    "situacao" "text" DEFAULT 'Ativo'::"text"
);


ALTER TABLE "public"."motoristas" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."movimentacoes" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "filial_id" "uuid",
    "descricao" "text",
    "entrada_amb" integer DEFAULT 0,
    "entrada_vinte" integer DEFAULT 0,
    "saida_amb" integer DEFAULT 0,
    "saida_vinte" integer DEFAULT 0,
    "updated_at" timestamp without time zone DEFAULT "now"(),
    "empresa_id" "uuid",
    "produto_id" "uuid",
    "cacl_id" "uuid",
    "placa" "text"[],
    "anp" boolean DEFAULT false NOT NULL,
    "cliente" "text",
    "codigo" integer,
    "observacoes" "text",
    "quantidade" numeric,
    "forma_pagamento" "text",
    "usuario_id" "uuid",
    "uf" "text",
    "status_circuito_orig" numeric DEFAULT '1'::numeric,
    "tipo_op" "text" DEFAULT ''::"text",
    "motorista_id" "uuid",
    "transportadora_id" "uuid",
    "filial_origem_id" "uuid",
    "filial_destino_id" "uuid",
    "tipo_mov" "text" DEFAULT ''::"text",
    "ts_mov" timestamp without time zone DEFAULT "now"() NOT NULL,
    "data_carga" timestamp with time zone,
    "data_descarga" timestamp with time zone,
    "tipo_mov_orig" "text",
    "tipo_mov_dest" "text",
    "ordem_id" "uuid",
    "nota_fiscal" "text",
    "status_circuito_dest" numeric DEFAULT '1'::numeric,
    "data_mov" timestamp without time zone DEFAULT "now"(),
    CONSTRAINT "entrada_amb_non_negative" CHECK (("entrada_amb" >= 0)),
    CONSTRAINT "entrada_vinte_non_negative" CHECK (("entrada_vinte" >= 0)),
    CONSTRAINT "saida_amb_non_negative" CHECK (("saida_amb" >= 0)),
    CONSTRAINT "saida_vinte_non_negative" CHECK (("saida_vinte" >= 0))
);


ALTER TABLE "public"."movimentacoes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."movimentacoes_tanque" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "movimentacao_id" "uuid",
    "tanque_id" "uuid",
    "produto_id" "uuid",
    "data_mov" timestamp without time zone DEFAULT ("now"() AT TIME ZONE 'America/Sao_Paulo'::"text"),
    "cliente" "text",
    "entrada_amb" integer DEFAULT 0,
    "entrada_vinte" integer DEFAULT 0,
    "saida_amb" integer DEFAULT 0,
    "saida_vinte" integer DEFAULT 0,
    "descricao" "text",
    "cacl_id" "uuid",
    CONSTRAINT "movimentacoes_tanque_entrada_amb_non_negative" CHECK (("entrada_amb" >= 0)),
    CONSTRAINT "movimentacoes_tanque_entrada_vinte_non_negative" CHECK (("entrada_vinte" >= 0)),
    CONSTRAINT "movimentacoes_tanque_saida_amb_non_negative" CHECK (("saida_amb" >= 0)),
    CONSTRAINT "movimentacoes_tanque_saida_vinte_non_negative" CHECK (("saida_vinte" >= 0))
);


ALTER TABLE "public"."movimentacoes_tanque" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."ordens" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "empresa_id" "uuid" NOT NULL,
    "filial_id" "uuid" NOT NULL,
    "usuario_id" "uuid" NOT NULL,
    "tipo" "text" DEFAULT 'venda'::"text" NOT NULL,
    "n_controle" character varying(7),
    "data_ordem" timestamp with time zone
);


ALTER TABLE "public"."ordens" OWNER TO "postgres";


COMMENT ON COLUMN "public"."ordens"."n_controle" IS 'Número de controle no formato OD-XXXX (ex: OD-3A4F)';



CREATE TABLE IF NOT EXISTS "public"."ordens_analises" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "numero_controle" character varying(50) NOT NULL,
    "data_criacao" timestamp without time zone DEFAULT ("now"() AT TIME ZONE 'America/Sao_Paulo'::"text"),
    "data_analise" "date" NOT NULL,
    "hora_analise" time without time zone NOT NULL,
    "tipo_operacao" character varying(20),
    "transportadora" character varying(100),
    "motorista" character varying(100),
    "notas_fiscais" character varying(50),
    "placa_cavalo" character varying(10),
    "carreta1" character varying(10),
    "carreta2" character varying(10),
    "produto_id" "uuid",
    "produto_nome" character varying(100),
    "temperatura_amostra" numeric(4,1),
    "densidade_observada" numeric(5,4),
    "temperatura_ct" numeric(4,1),
    "densidade_20c" numeric(5,4),
    "fator_correcao" numeric(6,4),
    "origem_ambiente" integer,
    "destino_ambiente" integer,
    "origem_20c" integer,
    "destino_20c" integer,
    "data_conclusao" timestamp with time zone,
    "usuario_id" "uuid",
    "criado_em" timestamp with time zone DEFAULT "now"(),
    "atualizado_em" timestamp with time zone DEFAULT "now"(),
    "filial_id" "uuid",
    "movimentacao_id" "uuid",
    "created_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    "updated_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    "tipo_analise" "text",
    CONSTRAINT "ordens_analises_tipo_operacao_check" CHECK ((("tipo_operacao")::"text" = ANY ((ARRAY['Carga'::character varying, 'Descarga'::character varying])::"text"[])))
);


ALTER TABLE "public"."ordens_analises" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."percentual_mistura" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "data" "date",
    "produto_id" "uuid",
    "percentual" numeric
);


ALTER TABLE "public"."percentual_mistura" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."permissoes" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "id_usuario" "uuid",
    "id_sessao" "uuid",
    "permitido" boolean DEFAULT true
);


ALTER TABLE "public"."permissoes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."produtos" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "codigo" integer NOT NULL,
    "nome" "text" NOT NULL,
    "nome_dois" "text",
    "produto_um" "uuid",
    "produto_dois" "uuid"
);

ALTER TABLE ONLY "public"."produtos" FORCE ROW LEVEL SECURITY;


ALTER TABLE "public"."produtos" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."produtos_new_codigo_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."produtos_new_codigo_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."produtos_new_codigo_seq" OWNED BY "public"."produtos"."codigo";



CREATE TABLE IF NOT EXISTS "public"."saldo_tanque_diario" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "tanque_id" "uuid" NOT NULL,
    "data_mov" timestamp without time zone DEFAULT ("now"() AT TIME ZONE 'America/Sao_Paulo'::"text") NOT NULL,
    "saldo" numeric NOT NULL,
    "created_at" timestamp without time zone DEFAULT ("now"() AT TIME ZONE 'America/Sao_Paulo'::"text") NOT NULL,
    "cacl_id" "uuid"
);


ALTER TABLE "public"."saldo_tanque_diario" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."tanques" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "referencia" "text" NOT NULL,
    "id_filial" "uuid" NOT NULL,
    "capacidade" "text" NOT NULL,
    "prioridade" numeric,
    "id_produto" "uuid",
    "status" "text" DEFAULT 'Em operação'::"text" NOT NULL,
    "lastro" numeric
);


ALTER TABLE "public"."tanques" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."tcd_anidro_hidratado_vw" WITH ("security_invoker"='on') AS
 SELECT "Temp.Obs." AS "temperatura_obs",
    "0,7715" AS "d_07715",
    "0,771" AS "d_07710",
    "0,7705" AS "d_07705",
    "0,77" AS "d_07700",
    "0,772" AS "d_07720",
    "0,7725" AS "d_07725",
    "0,773" AS "d_07730",
    "0,7735" AS "d_07735",
    "0,774" AS "d_07740",
    "0,7745" AS "d_07745",
    "0,775" AS "d_07750",
    "0,7755" AS "d_07755",
    "0,776" AS "d_07760",
    "0,7765" AS "d_07765",
    "0,777" AS "d_07770",
    "0,7775" AS "d_07775",
    "0,778" AS "d_07780",
    "0,7785" AS "d_07785",
    "0,779" AS "d_07790",
    "0,7795" AS "d_07795",
    "0,78" AS "d_07800",
    "0,7805" AS "d_07805",
    "0,781" AS "d_07810",
    "0,7815" AS "d_07815",
    "0,782" AS "d_07820",
    "0,7825" AS "d_07825",
    "0,783" AS "d_07830",
    "0,7835" AS "d_07835",
    "0,784" AS "d_07840",
    "0,7845" AS "d_07845",
    "0,785" AS "d_07850",
    "0,786" AS "d_07860",
    "0,787" AS "d_07870",
    "0,788" AS "d_07880",
    "0,789" AS "d_07890",
    "0,79" AS "d_07900",
    "0,791" AS "d_07910",
    "0,792" AS "d_07920",
    "0,793" AS "d_07930",
    "0,794" AS "d_07940",
    "0,795" AS "d_07950",
    "0,796" AS "d_07960",
    "0,797" AS "d_07970",
    "0,798" AS "d_07980",
    "0,799" AS "d_07990",
    "0,8" AS "d_08000",
    "0,801" AS "d_08010",
    "0,802" AS "d_08020",
    "0,803" AS "d_08030",
    "0,804" AS "d_08040",
    "0,805" AS "d_08050",
    "0,806" AS "d_08060",
    "0,807" AS "d_08070",
    "0,808" AS "d_08080",
    "0,809" AS "d_08090",
    "0,81" AS "d_08100",
    "0,811" AS "d_08110",
    "0,812" AS "d_08120",
    "0,813" AS "d_08130",
    "0,814" AS "d_08140",
    "0,815" AS "d_08150",
    "0,816" AS "d_08160",
    "0,817" AS "d_08170",
    "0,818" AS "d_08180",
    "0,819" AS "d_08190"
   FROM "public"."TCD_anidro_hidratado";


ALTER VIEW "public"."tcd_anidro_hidratado_vw" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."tcd_gasolina_diesel_vw" WITH ("security_invoker"='on') AS
 SELECT "Temp.Obs." AS "temperatura_obs",
    "0,6990" AS "d_06990",
    "0,7000" AS "d_07000",
    "0,7010" AS "d_07010",
    "0,7020" AS "d_07020",
    "0,7030" AS "d_07030",
    "0,7040" AS "d_07040",
    "0,7050" AS "d_07050",
    "0,7060" AS "d_07060",
    "0,7070" AS "d_07070",
    "0,7080" AS "d_07080",
    "0,7090" AS "d_07090",
    "0,7100" AS "d_07100",
    "0,7110" AS "d_07110",
    "0,7120" AS "d_07120",
    "0,7130" AS "d_07130",
    "0,7140" AS "d_07140",
    "0,7150" AS "d_07150",
    "0,7160" AS "d_07160",
    "0,7170" AS "d_07170",
    "0,7180" AS "d_07180",
    "0,7190" AS "d_07190",
    "0,7200" AS "d_07200",
    "0,7210" AS "d_07210",
    "0,7220" AS "d_07220",
    "0,7230" AS "d_07230",
    "0,7240" AS "d_07240",
    "0,7250" AS "d_07250",
    "0,7260" AS "d_07260",
    "0,7270" AS "d_07270",
    "0,7280" AS "d_07280",
    "0,7290" AS "d_07290",
    "0,7300" AS "d_07300",
    "0,7310" AS "d_07310",
    "0,7320" AS "d_07320",
    "0,7330" AS "d_07330",
    "0,7340" AS "d_07340",
    "0,7350" AS "d_07350",
    "0,7360" AS "d_07360",
    "0,7370" AS "d_07370",
    "0,7380" AS "d_07380",
    "0,7390" AS "d_07390",
    "0,7400" AS "d_07400",
    "0,7410" AS "d_07410",
    "0,7420" AS "d_07420",
    "0,7430" AS "d_07430",
    "0,7440" AS "d_07440",
    "0,7450" AS "d_07450",
    "0,7460" AS "d_07460",
    "0,7470" AS "d_07470",
    "0,7480" AS "d_07480",
    "0,7490" AS "d_07490",
    "0,7500" AS "d_07500",
    "0,7510" AS "d_07510",
    "0,7520" AS "d_07520",
    "0,7530" AS "d_07530",
    "0,7540" AS "d_07540",
    "0,7550" AS "d_07550",
    "0,7560" AS "d_07560",
    "0,7570" AS "d_07570",
    "0,7580" AS "d_07580",
    "0,7590" AS "d_07590",
    "0,7600" AS "d_07600",
    "0,7610" AS "d_07610",
    "0,7620" AS "d_07620",
    "0,7630" AS "d_07630",
    "0,7640" AS "d_07640",
    "0,7650" AS "d_07650",
    "0,7660" AS "d_07660",
    "0,7670" AS "d_07670",
    "0,7680" AS "d_07680",
    "0,7690" AS "d_07690",
    "0,7700" AS "d_07700",
    "0,7710" AS "d_07710",
    "0,7720" AS "d_07720",
    "0,7730" AS "d_07730",
    "0,7740" AS "d_07740",
    "0,7750" AS "d_07750",
    "0,7760" AS "d_07760",
    "0,7770" AS "d_07770",
    "0,7780" AS "d_07780",
    "0,7790" AS "d_07790",
    "0,7800" AS "d_07800",
    "0,7810" AS "d_07810",
    "0,7820" AS "d_07820",
    "0,7830" AS "d_07830",
    "0,7840" AS "d_07840",
    "0,7850" AS "d_07850",
    "0,7860" AS "d_07860",
    "0,7870" AS "d_07870",
    "0,7880" AS "d_07880",
    "0,7890" AS "d_07890",
    "0,7900" AS "d_07900",
    "0,7910" AS "d_07910",
    "0,7920" AS "d_07920",
    "0,7930" AS "d_07930",
    "0,7940" AS "d_07940",
    "0,7950" AS "d_07950",
    "0,7960" AS "d_07960",
    "0,7970" AS "d_07970",
    "0,7980" AS "d_07980",
    "0,7990" AS "d_07990",
    "0,8000" AS "d_08000",
    "0,8010" AS "d_08010",
    "0,8020" AS "d_08020",
    "0,8030" AS "d_08030",
    "0,8040" AS "d_08040",
    "0,8050" AS "d_08050",
    "0,8060" AS "d_08060",
    "0,8070" AS "d_08070",
    "0,8080" AS "d_08080",
    "0,8090" AS "d_08090",
    "0,8100" AS "d_08100",
    "0,8110" AS "d_08110",
    "0,8120" AS "d_08120",
    "0,8130" AS "d_08130",
    "0,8140" AS "d_08140",
    "0,8150" AS "d_08150",
    "0,8160" AS "d_08160",
    "0,8170" AS "d_08170",
    "0,8180" AS "d_08180",
    "0,8190" AS "d_08190",
    "0,8200" AS "d_08200",
    "0,8210" AS "d_08210",
    "0,8220" AS "d_08220",
    "0,8230" AS "d_08230",
    "0,8240" AS "d_08240",
    "0,8250" AS "d_08250",
    "0,8260" AS "d_08260",
    "0,8270" AS "d_08270",
    "0,8280" AS "d_08280",
    "0,8290" AS "d_08290",
    "0,8300" AS "d_08300",
    "0,8310" AS "d_08310",
    "0,8320" AS "d_08320",
    "0,8330" AS "d_08330",
    "0,8340" AS "d_08340",
    "0,8350" AS "d_08350",
    "0,8360" AS "d_08360",
    "0,8370" AS "d_08370",
    "0,8380" AS "d_08380",
    "0,8390" AS "d_08390",
    "0,8400" AS "d_08400",
    "0,8410" AS "d_08410",
    "0,8420" AS "d_08420",
    "0,8430" AS "d_08430",
    "0,8440" AS "d_08440",
    "0,8450" AS "d_08450",
    "0,8460" AS "d_08460",
    "0,8470" AS "d_08470",
    "0,8480" AS "d_08480",
    "0,8490" AS "d_08490",
    "0,8500" AS "d_08500",
    "0,8510" AS "d_08510",
    "0,8520" AS "d_08520",
    "0,8530" AS "d_08530",
    "0,8540" AS "d_08540",
    "0,8550" AS "d_08550",
    "0,8560" AS "d_08560",
    "0,8570" AS "d_08570",
    "0,8580" AS "d_08580",
    "0,8590" AS "d_08590",
    "0,8600" AS "d_08600",
    "0,8610" AS "d_08610",
    "0,8620" AS "d_08620",
    "0,8630" AS "d_08630",
    "0,864" AS "d_08640",
    "0,865" AS "d_08650",
    "0,866" AS "d_08660",
    "0,867" AS "d_08670",
    "0,868" AS "d_08680",
    "0,869" AS "d_08690",
    "0,870" AS "d_08700",
    "0,871" AS "d_08710",
    "0,872" AS "d_08720",
    "0,873" AS "d_08730",
    "0,874" AS "d_08740",
    "0,875" AS "d_08750",
    "0,876" AS "d_08760",
    "0,877" AS "d_08770",
    "0,878" AS "d_08780",
    "0,879" AS "d_08790",
    "0,880" AS "d_08800",
    "0,881" AS "d_08810",
    "0,882" AS "d_08820",
    "0,883" AS "d_08830",
    "0,884" AS "d_08840",
    "0,885" AS "d_08850",
    "0,886" AS "d_08860",
    "0,887" AS "d_08870",
    "0,888" AS "d_08880",
    "0,889" AS "d_08890",
    "0,890" AS "d_08900",
    "0,891" AS "d_08910",
    "0,892" AS "d_08920",
    "0,893" AS "d_08930",
    "0,894" AS "d_08940",
    "0,895" AS "d_08950",
    "0,896" AS "d_08960",
    "0,897" AS "d_08970",
    "0,898" AS "d_08980",
    "0,899" AS "d_08990",
    "0,9" AS "d_09000",
    "0,901" AS "d_09010",
    "0,902" AS "d_09020",
    "0,903" AS "d_09030",
    "0,904" AS "d_09040",
    "0,905" AS "d_09050",
    "0,906" AS "d_09060",
    "0,907" AS "d_09070",
    "0,908" AS "d_09080",
    "0,909" AS "d_09090"
   FROM "public"."TCD_gasolina_diesel";


ALTER VIEW "public"."tcd_gasolina_diesel_vw" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."tcv_anidro_hidratado_vw" WITH ("security_invoker"='on') AS
 SELECT "Temp.Obs." AS "temperatura_obs",
    "0,7" AS "v_07000",
    "0,7893" AS "v_07893",
    "0,7985" AS "v_07985",
    "0,8098" AS "v_08098",
    "0,8125" AS "v_08125",
    "0,8153" AS "v_08153",
    "0,8208" AS "v_08208",
    "0,8232" AS "v_08232"
   FROM "public"."TCV_anidro_hidratado";


ALTER VIEW "public"."tcv_anidro_hidratado_vw" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."tcv_gasolina_diesel_vw" WITH ("security_invoker"='on') AS
 SELECT "Temp.Obs." AS "temperatura_obs",
    "0,7050" AS "v_07050",
    "0,7060" AS "v_07060",
    "0,7070" AS "v_07070",
    "0,7080" AS "v_07080",
    "0,7090" AS "v_07090",
    "0,7100" AS "v_07100",
    "0,7110" AS "v_07110",
    "0,7120" AS "v_07120",
    "0,7130" AS "v_07130",
    "0,7140" AS "v_07140",
    "0,7150" AS "v_07150",
    "0,7160" AS "v_07160",
    "0,7170" AS "v_07170",
    "0,7180" AS "v_07180",
    "0,7190" AS "v_07190",
    "0,7200" AS "v_07200",
    "0,7210" AS "v_07210",
    "0,7220" AS "v_07220",
    "0,7230" AS "v_07230",
    "0,7240" AS "v_07240",
    "0,7250" AS "v_07250",
    "0,7260" AS "v_07260",
    "0,7270" AS "v_07270",
    "0,7280" AS "v_07280",
    "0,7290" AS "v_07290",
    "0,7300" AS "v_07300",
    "0,7310" AS "v_07310",
    "0,7320" AS "v_07320",
    "0,7330" AS "v_07330",
    "0,7340" AS "v_07340",
    "0,7350" AS "v_07350",
    "0,7360" AS "v_07360",
    "0,7370" AS "v_07370",
    "0,7380" AS "v_07380",
    "0,7390" AS "v_07390",
    "0,7400" AS "v_07400",
    "0,7410" AS "v_07410",
    "0,7420" AS "v_07420",
    "0,7430" AS "v_07430",
    "0,7440" AS "v_07440",
    "0,7450" AS "v_07450",
    "0,7460" AS "v_07460",
    "0,7470" AS "v_07470",
    "0,7480" AS "v_07480",
    "0,7490" AS "v_07490",
    "0,7500" AS "v_07500",
    "0,7510" AS "v_07510",
    "0,7520" AS "v_07520",
    "0,7530" AS "v_07530",
    "0,7540" AS "v_07540",
    "0,7550" AS "v_07550",
    "0,7560" AS "v_07560",
    "0,7570" AS "v_07570",
    "0,7580" AS "v_07580",
    "0,7590" AS "v_07590",
    "0,7600" AS "v_07600",
    "0,7610" AS "v_07610",
    "0,7620" AS "v_07620",
    "0,7630" AS "v_07630",
    "0,7640" AS "v_07640",
    "0,7650" AS "v_07650",
    "0,7660" AS "v_07660",
    "0,7670" AS "v_07670",
    "0,7680" AS "v_07680",
    "0,7690" AS "v_07690",
    "0,7700" AS "v_07700",
    "0,7710" AS "v_07710",
    "0,7720" AS "v_07720",
    "0,7730" AS "v_07730",
    "0,7740" AS "v_07740",
    "0,7750" AS "v_07750",
    "0,7760" AS "v_07760",
    "0,7770" AS "v_07770",
    "0,7780" AS "v_07780",
    "0,7790" AS "v_07790",
    "0,7800" AS "v_07800",
    "0,7810" AS "v_07810",
    "0,7820" AS "v_07820",
    "0,7830" AS "v_07830",
    "0,7840" AS "v_07840",
    "0,7850" AS "v_07850",
    "0,7860" AS "v_07860",
    "0,7870" AS "v_07870",
    "0,7880" AS "v_07880",
    "0,7890" AS "v_07890",
    "0,7900" AS "v_07900",
    "0,7910" AS "v_07910",
    "0,7920" AS "v_07920",
    "0,7930" AS "v_07930",
    "0,7940" AS "v_07940",
    "0,7950" AS "v_07950",
    "0,7960" AS "v_07960",
    "0,7970" AS "v_07970",
    "0,7980" AS "v_07980",
    "0,7990" AS "v_07990",
    "0,8000" AS "v_08000",
    "0,8010" AS "v_08010",
    "0,8020" AS "v_08020",
    "0,8030" AS "v_08030",
    "0,8040" AS "v_08040",
    "0,8050" AS "v_08050",
    "0,8060" AS "v_08060",
    "0,8070" AS "v_08070",
    "0,8080" AS "v_08080",
    "0,8090" AS "v_08090",
    "0,8100" AS "v_08100",
    "0,8110" AS "v_08110",
    "0,8120" AS "v_08120",
    "0,8130" AS "v_08130",
    "0,8140" AS "v_08140",
    "0,8150" AS "v_08150",
    "0,8160" AS "v_08160",
    "0,8170" AS "v_08170",
    "0,8180" AS "v_08180",
    "0,8190" AS "v_08190",
    "0,8200" AS "v_08200",
    "0,8210" AS "v_08210",
    "0,8220" AS "v_08220",
    "0,8230" AS "v_08230",
    "0,8240" AS "v_08240",
    "0,8250" AS "v_08250",
    "0,8260" AS "v_08260",
    "0,8270" AS "v_08270",
    "0,8280" AS "v_08280",
    "0,8290" AS "v_08290",
    "0,8300" AS "v_08300",
    "0,8310" AS "v_08310",
    "0,8320" AS "v_08320",
    "0,8330" AS "v_08330",
    "0,8340" AS "v_08340",
    "0,8350" AS "v_08350",
    "0,8360" AS "v_08360",
    "0,8370" AS "v_08370",
    "0,8380" AS "v_08380",
    "0,8390" AS "v_08390",
    "0,8400" AS "v_08400",
    "0,8410" AS "v_08410",
    "0,8420" AS "v_08420",
    "0,8430" AS "v_08430",
    "0,8440" AS "v_08440",
    "0,8450" AS "v_08450",
    "0,8460" AS "v_08460",
    "0,8470" AS "v_08470",
    "0,8480" AS "v_08480",
    "0,8490" AS "v_08490",
    "0,8500" AS "v_08500",
    "0,8510" AS "v_08510",
    "0,8520" AS "v_08520",
    "0,8530" AS "v_08530",
    "0,8540" AS "v_08540",
    "0,8550" AS "v_08550",
    "0,8560" AS "v_08560",
    "0,8570" AS "v_08570",
    "0,8580" AS "v_08580",
    "0,8590" AS "v_08590",
    "0,8600" AS "v_08600",
    "0,8610" AS "v_08610",
    "0,8620" AS "v_08620",
    "0,8630" AS "v_08630",
    "0,8640" AS "v_08640",
    "0,8650" AS "v_08650",
    "0,8660" AS "v_08660",
    "0,8670" AS "v_08670",
    "0,8680" AS "v_08680",
    "0,8690" AS "v_08690",
    "0,8700" AS "v_08700",
    "0,8710" AS "v_08710",
    "0,8720" AS "v_08720",
    "0,8730" AS "v_08730",
    "0,8740" AS "v_08740",
    "0,8750" AS "v_08750",
    "0,8760" AS "v_08760",
    "0,8770" AS "v_08770",
    "0,8780" AS "v_08780"
   FROM "public"."TCV_gasolina_diesel";


ALTER VIEW "public"."tcv_gasolina_diesel_vw" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."transportadoras" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "nome" "text",
    "cnpj" "text",
    "inscricao_estadual" "text",
    "telefone_um" "text",
    "telefone_dois" "text",
    "situacao" "text",
    "nome_dois" "text",
    "tipo" "text"
);


ALTER TABLE "public"."transportadoras" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."usuarios" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "nome" "text" NOT NULL,
    "email" "text" NOT NULL,
    "nivel" integer NOT NULL,
    "id_filial" "uuid",
    "celular" "text",
    "funcao" "text",
    "status" "text",
    "senha_temporaria" boolean DEFAULT false,
    "redefinicao_senha" boolean,
    "Nome_apelido" "text",
    "id_filial_segunda" "uuid",
    "empresa_id" "uuid",
    CONSTRAINT "usuarios_nivel_check" CHECK (("nivel" = ANY (ARRAY[1, 2, 3])))
);

ALTER TABLE ONLY "public"."usuarios" FORCE ROW LEVEL SECURITY;


ALTER TABLE "public"."usuarios" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."veiculos_geral" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "placa" "text" NOT NULL,
    "renavam" "text",
    "transportadora_id" "uuid",
    "status" "text" DEFAULT 'ativo'::"text",
    "tanques" integer[]
);


ALTER TABLE "public"."veiculos_geral" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."view_placas_distintas" WITH ("security_invoker"='true') AS
 SELECT
        CASE
            WHEN (("tanques" IS NULL) OR ("array_length"("tanques", 1) IS NULL)) THEN "placa"
            ELSE NULL::"text"
        END AS "placas_cavalo",
        CASE
            WHEN ("array_length"("tanques", 1) > 0) THEN "placa"
            ELSE NULL::"text"
        END AS "placas_reboques",
    "tanques"
   FROM ( SELECT "equipamentos"."placa",
            "equipamentos"."tanques"
           FROM "public"."equipamentos"
        UNION ALL
         SELECT "veiculos_geral"."placa",
            "veiculos_geral"."tanques"
           FROM "public"."veiculos_geral") "subconsulta";


ALTER VIEW "public"."view_placas_distintas" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."view_placas_tanques" WITH ("security_invoker"='true') AS
 SELECT "equipamentos"."placa" AS "placas",
    "equipamentos"."tanques"
   FROM "public"."equipamentos"
UNION
 SELECT "veiculos_geral"."placa" AS "placas",
    "veiculos_geral"."tanques"
   FROM "public"."veiculos_geral";


ALTER VIEW "public"."view_placas_tanques" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "storage"."buckets" (
    "id" "text" NOT NULL,
    "name" "text" NOT NULL,
    "owner" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "public" boolean DEFAULT false,
    "avif_autodetection" boolean DEFAULT false,
    "file_size_limit" bigint,
    "allowed_mime_types" "text"[],
    "owner_id" "text",
    "type" "storage"."buckettype" DEFAULT 'STANDARD'::"storage"."buckettype" NOT NULL
);


ALTER TABLE "storage"."buckets" OWNER TO "supabase_storage_admin";


COMMENT ON COLUMN "storage"."buckets"."owner" IS 'Field is deprecated, use owner_id instead';



CREATE TABLE IF NOT EXISTS "storage"."buckets_analytics" (
    "name" "text" NOT NULL,
    "type" "storage"."buckettype" DEFAULT 'ANALYTICS'::"storage"."buckettype" NOT NULL,
    "format" "text" DEFAULT 'ICEBERG'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "deleted_at" timestamp with time zone
);


ALTER TABLE "storage"."buckets_analytics" OWNER TO "supabase_storage_admin";


CREATE TABLE IF NOT EXISTS "storage"."buckets_vectors" (
    "id" "text" NOT NULL,
    "type" "storage"."buckettype" DEFAULT 'VECTOR'::"storage"."buckettype" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "storage"."buckets_vectors" OWNER TO "supabase_storage_admin";


CREATE TABLE IF NOT EXISTS "storage"."migrations" (
    "id" integer NOT NULL,
    "name" character varying(100) NOT NULL,
    "hash" character varying(40) NOT NULL,
    "executed_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE "storage"."migrations" OWNER TO "supabase_storage_admin";


CREATE TABLE IF NOT EXISTS "storage"."objects" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "bucket_id" "text",
    "name" "text",
    "owner" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "last_accessed_at" timestamp with time zone DEFAULT "now"(),
    "metadata" "jsonb",
    "path_tokens" "text"[] GENERATED ALWAYS AS ("string_to_array"("name", '/'::"text")) STORED,
    "version" "text",
    "owner_id" "text",
    "user_metadata" "jsonb"
);


ALTER TABLE "storage"."objects" OWNER TO "supabase_storage_admin";


COMMENT ON COLUMN "storage"."objects"."owner" IS 'Field is deprecated, use owner_id instead';



CREATE TABLE IF NOT EXISTS "storage"."s3_multipart_uploads" (
    "id" "text" NOT NULL,
    "in_progress_size" bigint DEFAULT 0 NOT NULL,
    "upload_signature" "text" NOT NULL,
    "bucket_id" "text" NOT NULL,
    "key" "text" NOT NULL COLLATE "pg_catalog"."C",
    "version" "text" NOT NULL,
    "owner_id" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "user_metadata" "jsonb"
);


ALTER TABLE "storage"."s3_multipart_uploads" OWNER TO "supabase_storage_admin";


CREATE TABLE IF NOT EXISTS "storage"."s3_multipart_uploads_parts" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "upload_id" "text" NOT NULL,
    "size" bigint DEFAULT 0 NOT NULL,
    "part_number" integer NOT NULL,
    "bucket_id" "text" NOT NULL,
    "key" "text" NOT NULL COLLATE "pg_catalog"."C",
    "etag" "text" NOT NULL,
    "owner_id" "text",
    "version" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "storage"."s3_multipart_uploads_parts" OWNER TO "supabase_storage_admin";


CREATE TABLE IF NOT EXISTS "storage"."vector_indexes" (
    "id" "text" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL COLLATE "pg_catalog"."C",
    "bucket_id" "text" NOT NULL,
    "data_type" "text" NOT NULL,
    "dimension" integer NOT NULL,
    "distance_metric" "text" NOT NULL,
    "metadata_configuration" "jsonb",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "storage"."vector_indexes" OWNER TO "supabase_storage_admin";


ALTER TABLE ONLY "auth"."refresh_tokens" ALTER COLUMN "id" SET DEFAULT "nextval"('"auth"."refresh_tokens_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."produtos" ALTER COLUMN "codigo" SET DEFAULT "nextval"('"public"."produtos_new_codigo_seq"'::"regclass");



ALTER TABLE ONLY "auth"."mfa_amr_claims"
    ADD CONSTRAINT "amr_id_pk" PRIMARY KEY ("id");



ALTER TABLE ONLY "auth"."audit_log_entries"
    ADD CONSTRAINT "audit_log_entries_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "auth"."flow_state"
    ADD CONSTRAINT "flow_state_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "auth"."identities"
    ADD CONSTRAINT "identities_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "auth"."identities"
    ADD CONSTRAINT "identities_provider_id_provider_unique" UNIQUE ("provider_id", "provider");



ALTER TABLE ONLY "auth"."instances"
    ADD CONSTRAINT "instances_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "auth"."mfa_amr_claims"
    ADD CONSTRAINT "mfa_amr_claims_session_id_authentication_method_pkey" UNIQUE ("session_id", "authentication_method");



ALTER TABLE ONLY "auth"."mfa_challenges"
    ADD CONSTRAINT "mfa_challenges_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "auth"."mfa_factors"
    ADD CONSTRAINT "mfa_factors_last_challenged_at_key" UNIQUE ("last_challenged_at");



ALTER TABLE ONLY "auth"."mfa_factors"
    ADD CONSTRAINT "mfa_factors_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "auth"."oauth_authorizations"
    ADD CONSTRAINT "oauth_authorizations_authorization_code_key" UNIQUE ("authorization_code");



ALTER TABLE ONLY "auth"."oauth_authorizations"
    ADD CONSTRAINT "oauth_authorizations_authorization_id_key" UNIQUE ("authorization_id");



ALTER TABLE ONLY "auth"."oauth_authorizations"
    ADD CONSTRAINT "oauth_authorizations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "auth"."oauth_client_states"
    ADD CONSTRAINT "oauth_client_states_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "auth"."oauth_clients"
    ADD CONSTRAINT "oauth_clients_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "auth"."oauth_consents"
    ADD CONSTRAINT "oauth_consents_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "auth"."oauth_consents"
    ADD CONSTRAINT "oauth_consents_user_client_unique" UNIQUE ("user_id", "client_id");



ALTER TABLE ONLY "auth"."one_time_tokens"
    ADD CONSTRAINT "one_time_tokens_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "auth"."refresh_tokens"
    ADD CONSTRAINT "refresh_tokens_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "auth"."refresh_tokens"
    ADD CONSTRAINT "refresh_tokens_token_unique" UNIQUE ("token");



ALTER TABLE ONLY "auth"."saml_providers"
    ADD CONSTRAINT "saml_providers_entity_id_key" UNIQUE ("entity_id");



ALTER TABLE ONLY "auth"."saml_providers"
    ADD CONSTRAINT "saml_providers_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "auth"."saml_relay_states"
    ADD CONSTRAINT "saml_relay_states_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "auth"."schema_migrations"
    ADD CONSTRAINT "schema_migrations_pkey" PRIMARY KEY ("version");



ALTER TABLE ONLY "auth"."sessions"
    ADD CONSTRAINT "sessions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "auth"."sso_domains"
    ADD CONSTRAINT "sso_domains_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "auth"."sso_providers"
    ADD CONSTRAINT "sso_providers_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "auth"."users"
    ADD CONSTRAINT "users_phone_key" UNIQUE ("phone");



ALTER TABLE ONLY "auth"."users"
    ADD CONSTRAINT "users_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."TCV_anidro_hidratado"
    ADD CONSTRAINT "TCV_anidro_hidratado_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."ajuda"
    ADD CONSTRAINT "ajuda_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."cadastros_pendentes"
    ADD CONSTRAINT "cadastros_pendentes_email_key" UNIQUE ("email");



ALTER TABLE ONLY "public"."cadastros_pendentes"
    ADD CONSTRAINT "cadastros_pendentes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."cacl"
    ADD CONSTRAINT "calculos_cacl_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."cards"
    ADD CONSTRAINT "cards_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."coletas_tanques"
    ADD CONSTRAINT "coletas_tanques_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."conjuntos"
    ADD CONSTRAINT "conjuntos_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."empresas"
    ADD CONSTRAINT "empresas_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."equipamentos"
    ADD CONSTRAINT "equipamentos_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."movimentacoes"
    ADD CONSTRAINT "estoques_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."filiais"
    ADD CONSTRAINT "filiais_cnpj_key" UNIQUE ("cnpj");



ALTER TABLE ONLY "public"."filiais"
    ADD CONSTRAINT "filiais_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."motoristas"
    ADD CONSTRAINT "motoristas_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."movimentacoes_tanque"
    ADD CONSTRAINT "movimentacoes_tanque_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."ordens_analises"
    ADD CONSTRAINT "ordens_analises_numero_controle_key" UNIQUE ("numero_controle");



ALTER TABLE ONLY "public"."ordens_analises"
    ADD CONSTRAINT "ordens_analises_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."ordens"
    ADD CONSTRAINT "ordens_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."percentual_mistura"
    ADD CONSTRAINT "percentual_mistura_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."permissoes"
    ADD CONSTRAINT "permissoes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."produtos"
    ADD CONSTRAINT "produtos_new_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."saldo_tanque_diario"
    ADD CONSTRAINT "saldo_tanque_diario_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."saldo_tanque_diario"
    ADD CONSTRAINT "saldo_tanque_diario_unq" UNIQUE ("tanque_id", "data_mov");



ALTER TABLE ONLY "public"."tanques"
    ADD CONSTRAINT "tanques_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."transportadoras"
    ADD CONSTRAINT "transportadoras_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."usuarios"
    ADD CONSTRAINT "usuarios_email_key" UNIQUE ("email");



ALTER TABLE ONLY "public"."usuarios"
    ADD CONSTRAINT "usuarios_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."veiculos_geral"
    ADD CONSTRAINT "veiculos_geral_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "storage"."buckets_analytics"
    ADD CONSTRAINT "buckets_analytics_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "storage"."buckets"
    ADD CONSTRAINT "buckets_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "storage"."buckets_vectors"
    ADD CONSTRAINT "buckets_vectors_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "storage"."migrations"
    ADD CONSTRAINT "migrations_name_key" UNIQUE ("name");



ALTER TABLE ONLY "storage"."migrations"
    ADD CONSTRAINT "migrations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "storage"."objects"
    ADD CONSTRAINT "objects_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "storage"."s3_multipart_uploads_parts"
    ADD CONSTRAINT "s3_multipart_uploads_parts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "storage"."s3_multipart_uploads"
    ADD CONSTRAINT "s3_multipart_uploads_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "storage"."vector_indexes"
    ADD CONSTRAINT "vector_indexes_pkey" PRIMARY KEY ("id");



CREATE INDEX "audit_logs_instance_id_idx" ON "auth"."audit_log_entries" USING "btree" ("instance_id");



CREATE UNIQUE INDEX "confirmation_token_idx" ON "auth"."users" USING "btree" ("confirmation_token") WHERE (("confirmation_token")::"text" !~ '^[0-9 ]*$'::"text");



CREATE UNIQUE INDEX "email_change_token_current_idx" ON "auth"."users" USING "btree" ("email_change_token_current") WHERE (("email_change_token_current")::"text" !~ '^[0-9 ]*$'::"text");



CREATE UNIQUE INDEX "email_change_token_new_idx" ON "auth"."users" USING "btree" ("email_change_token_new") WHERE (("email_change_token_new")::"text" !~ '^[0-9 ]*$'::"text");



CREATE INDEX "factor_id_created_at_idx" ON "auth"."mfa_factors" USING "btree" ("user_id", "created_at");



CREATE INDEX "flow_state_created_at_idx" ON "auth"."flow_state" USING "btree" ("created_at" DESC);



CREATE INDEX "identities_email_idx" ON "auth"."identities" USING "btree" ("email" "text_pattern_ops");



COMMENT ON INDEX "auth"."identities_email_idx" IS 'Auth: Ensures indexed queries on the email column';



CREATE INDEX "identities_user_id_idx" ON "auth"."identities" USING "btree" ("user_id");



CREATE INDEX "idx_auth_code" ON "auth"."flow_state" USING "btree" ("auth_code");



CREATE INDEX "idx_oauth_client_states_created_at" ON "auth"."oauth_client_states" USING "btree" ("created_at");



CREATE INDEX "idx_user_id_auth_method" ON "auth"."flow_state" USING "btree" ("user_id", "authentication_method");



CREATE INDEX "mfa_challenge_created_at_idx" ON "auth"."mfa_challenges" USING "btree" ("created_at" DESC);



CREATE UNIQUE INDEX "mfa_factors_user_friendly_name_unique" ON "auth"."mfa_factors" USING "btree" ("friendly_name", "user_id") WHERE (TRIM(BOTH FROM "friendly_name") <> ''::"text");



CREATE INDEX "mfa_factors_user_id_idx" ON "auth"."mfa_factors" USING "btree" ("user_id");



CREATE INDEX "oauth_auth_pending_exp_idx" ON "auth"."oauth_authorizations" USING "btree" ("expires_at") WHERE ("status" = 'pending'::"auth"."oauth_authorization_status");



CREATE INDEX "oauth_clients_deleted_at_idx" ON "auth"."oauth_clients" USING "btree" ("deleted_at");



CREATE INDEX "oauth_consents_active_client_idx" ON "auth"."oauth_consents" USING "btree" ("client_id") WHERE ("revoked_at" IS NULL);



CREATE INDEX "oauth_consents_active_user_client_idx" ON "auth"."oauth_consents" USING "btree" ("user_id", "client_id") WHERE ("revoked_at" IS NULL);



CREATE INDEX "oauth_consents_user_order_idx" ON "auth"."oauth_consents" USING "btree" ("user_id", "granted_at" DESC);



CREATE INDEX "one_time_tokens_relates_to_hash_idx" ON "auth"."one_time_tokens" USING "hash" ("relates_to");



CREATE INDEX "one_time_tokens_token_hash_hash_idx" ON "auth"."one_time_tokens" USING "hash" ("token_hash");



CREATE UNIQUE INDEX "one_time_tokens_user_id_token_type_key" ON "auth"."one_time_tokens" USING "btree" ("user_id", "token_type");



CREATE UNIQUE INDEX "reauthentication_token_idx" ON "auth"."users" USING "btree" ("reauthentication_token") WHERE (("reauthentication_token")::"text" !~ '^[0-9 ]*$'::"text");



CREATE UNIQUE INDEX "recovery_token_idx" ON "auth"."users" USING "btree" ("recovery_token") WHERE (("recovery_token")::"text" !~ '^[0-9 ]*$'::"text");



CREATE INDEX "refresh_tokens_instance_id_idx" ON "auth"."refresh_tokens" USING "btree" ("instance_id");



CREATE INDEX "refresh_tokens_instance_id_user_id_idx" ON "auth"."refresh_tokens" USING "btree" ("instance_id", "user_id");



CREATE INDEX "refresh_tokens_parent_idx" ON "auth"."refresh_tokens" USING "btree" ("parent");



CREATE INDEX "refresh_tokens_session_id_revoked_idx" ON "auth"."refresh_tokens" USING "btree" ("session_id", "revoked");



CREATE INDEX "refresh_tokens_updated_at_idx" ON "auth"."refresh_tokens" USING "btree" ("updated_at" DESC);



CREATE INDEX "saml_providers_sso_provider_id_idx" ON "auth"."saml_providers" USING "btree" ("sso_provider_id");



CREATE INDEX "saml_relay_states_created_at_idx" ON "auth"."saml_relay_states" USING "btree" ("created_at" DESC);



CREATE INDEX "saml_relay_states_for_email_idx" ON "auth"."saml_relay_states" USING "btree" ("for_email");



CREATE INDEX "saml_relay_states_sso_provider_id_idx" ON "auth"."saml_relay_states" USING "btree" ("sso_provider_id");



CREATE INDEX "sessions_not_after_idx" ON "auth"."sessions" USING "btree" ("not_after" DESC);



CREATE INDEX "sessions_oauth_client_id_idx" ON "auth"."sessions" USING "btree" ("oauth_client_id");



CREATE INDEX "sessions_user_id_idx" ON "auth"."sessions" USING "btree" ("user_id");



CREATE UNIQUE INDEX "sso_domains_domain_idx" ON "auth"."sso_domains" USING "btree" ("lower"("domain"));



CREATE INDEX "sso_domains_sso_provider_id_idx" ON "auth"."sso_domains" USING "btree" ("sso_provider_id");



CREATE UNIQUE INDEX "sso_providers_resource_id_idx" ON "auth"."sso_providers" USING "btree" ("lower"("resource_id"));



CREATE INDEX "sso_providers_resource_id_pattern_idx" ON "auth"."sso_providers" USING "btree" ("resource_id" "text_pattern_ops");



CREATE UNIQUE INDEX "unique_phone_factor_per_user" ON "auth"."mfa_factors" USING "btree" ("user_id", "phone");



CREATE INDEX "user_id_created_at_idx" ON "auth"."sessions" USING "btree" ("user_id", "created_at");



CREATE UNIQUE INDEX "users_email_partial_key" ON "auth"."users" USING "btree" ("email") WHERE ("is_sso_user" = false);



COMMENT ON INDEX "auth"."users_email_partial_key" IS 'Auth: A partial unique index that applies only when is_sso_user is false';



CREATE INDEX "users_instance_id_email_idx" ON "auth"."users" USING "btree" ("instance_id", "lower"(("email")::"text"));



CREATE INDEX "users_instance_id_idx" ON "auth"."users" USING "btree" ("instance_id");



CREATE INDEX "users_is_anonymous_idx" ON "auth"."users" USING "btree" ("is_anonymous");



CREATE INDEX "coletas_tanques_idx_movimentacao" ON "public"."coletas_tanques" USING "btree" ("movimentacao_id");



CREATE INDEX "coletas_tanques_idx_produto" ON "public"."coletas_tanques" USING "btree" ("produto_id");



CREATE INDEX "idx_cacl_data" ON "public"."cacl" USING "btree" ("data");



CREATE INDEX "idx_cacl_filial_id" ON "public"."cacl" USING "btree" ("filial_id");



CREATE INDEX "idx_cacl_horario_inicial" ON "public"."cacl" USING "btree" ("horario_inicial");



CREATE INDEX "idx_cacl_numero_controle" ON "public"."cacl" USING "btree" ("numero_controle");



CREATE INDEX "idx_cacl_tanque_filial_data" ON "public"."cacl" USING "btree" ("tanque_id", "filial_id", "data");



CREATE INDEX "idx_cacl_tanque_id" ON "public"."cacl" USING "btree" ("tanque_id");



CREATE INDEX "idx_mov_tanque_movimentacao" ON "public"."movimentacoes_tanque" USING "btree" ("movimentacao_id");



CREATE INDEX "idx_mov_tanque_produto" ON "public"."movimentacoes_tanque" USING "btree" ("produto_id");



CREATE INDEX "idx_mov_tanque_tanque" ON "public"."movimentacoes_tanque" USING "btree" ("tanque_id");



CREATE INDEX "idx_mov_tanque_ts" ON "public"."movimentacoes_tanque" USING "btree" ("data_mov");



CREATE INDEX "idx_ordens_analises_criado_em" ON "public"."ordens_analises" USING "btree" ("criado_em");



CREATE INDEX "idx_ordens_analises_data_analise" ON "public"."ordens_analises" USING "btree" ("data_analise");



CREATE INDEX "idx_ordens_analises_numero_controle" ON "public"."ordens_analises" USING "btree" ("numero_controle");



CREATE INDEX "idx_ordens_analises_produto_id" ON "public"."ordens_analises" USING "btree" ("produto_id");



CREATE INDEX "idx_ordens_analises_usuario_id" ON "public"."ordens_analises" USING "btree" ("usuario_id");



CREATE INDEX "idx_tanques_id_base" ON "public"."tanques" USING "btree" ("id_filial");



CREATE INDEX "mov_tanque_idx_tanque_data" ON "public"."movimentacoes_tanque" USING "btree" ("tanque_id", "data_mov");



CREATE INDEX "saldo_tanque_diario_idx_data" ON "public"."saldo_tanque_diario" USING "btree" ("data_mov");



CREATE INDEX "saldo_tanque_diario_idx_tanque_data" ON "public"."saldo_tanque_diario" USING "btree" ("tanque_id", "data_mov");



CREATE UNIQUE INDEX "bname" ON "storage"."buckets" USING "btree" ("name");



CREATE UNIQUE INDEX "bucketid_objname" ON "storage"."objects" USING "btree" ("bucket_id", "name");



CREATE UNIQUE INDEX "buckets_analytics_unique_name_idx" ON "storage"."buckets_analytics" USING "btree" ("name") WHERE ("deleted_at" IS NULL);



CREATE INDEX "idx_multipart_uploads_list" ON "storage"."s3_multipart_uploads" USING "btree" ("bucket_id", "key", "created_at");



CREATE INDEX "idx_objects_bucket_id_name" ON "storage"."objects" USING "btree" ("bucket_id", "name" COLLATE "C");



CREATE INDEX "idx_objects_bucket_id_name_lower" ON "storage"."objects" USING "btree" ("bucket_id", "lower"("name") COLLATE "C");



CREATE INDEX "name_prefix_search" ON "storage"."objects" USING "btree" ("name" "text_pattern_ops");



CREATE UNIQUE INDEX "vector_indexes_name_bucket_id_idx" ON "storage"."vector_indexes" USING "btree" ("name", "bucket_id");



CREATE OR REPLACE TRIGGER "atualizar_timestamp_trigger" BEFORE UPDATE ON "public"."ordens_analises" FOR EACH ROW EXECUTE FUNCTION "public"."atualizar_timestamp"();



CREATE OR REPLACE TRIGGER "tr_gerar_numero_controle_ordens" BEFORE INSERT ON "public"."ordens" FOR EACH ROW EXECUTE FUNCTION "public"."gerar_numero_controle"();



CREATE OR REPLACE TRIGGER "trg_alimentar_saldo_tanque_diario" AFTER INSERT OR UPDATE ON "public"."cacl" FOR EACH ROW EXECUTE FUNCTION "public"."alimentar_saldo_tanque_diario"();



CREATE OR REPLACE TRIGGER "trg_movimentacoes_after_upsert" AFTER INSERT OR UPDATE ON "public"."movimentacoes" FOR EACH ROW EXECUTE FUNCTION "public"."fn_gerar_movimentacao_tanque"();



CREATE OR REPLACE TRIGGER "trg_movimentacoes_transf_after_upsert" AFTER INSERT OR UPDATE ON "public"."movimentacoes" FOR EACH ROW EXECUTE FUNCTION "public"."alimentar_movim_tanque_transf"();



CREATE OR REPLACE TRIGGER "trigger_gerar_numero_controle" BEFORE INSERT ON "public"."ordens_analises" FOR EACH ROW WHEN ((("new"."numero_controle" IS NULL) OR (("new"."numero_controle")::"text" = ''::"text"))) EXECUTE FUNCTION "public"."gerar_numero_controle"();



CREATE OR REPLACE TRIGGER "trigger_gerar_numero_controle_cacl" BEFORE INSERT ON "public"."cacl" FOR EACH ROW WHEN ((("new"."numero_controle" IS NULL) OR (TRIM(BOTH FROM "new"."numero_controle") = ''::"text"))) EXECUTE FUNCTION "public"."gerar_numero_controle"();



CREATE OR REPLACE TRIGGER "trigger_update_atualizado_em" BEFORE UPDATE ON "public"."ordens_analises" FOR EACH ROW EXECUTE FUNCTION "public"."update_atualizado_em"();



CREATE OR REPLACE TRIGGER "enforce_bucket_name_length_trigger" BEFORE INSERT OR UPDATE OF "name" ON "storage"."buckets" FOR EACH ROW EXECUTE FUNCTION "storage"."enforce_bucket_name_length"();



CREATE OR REPLACE TRIGGER "protect_buckets_delete" BEFORE DELETE ON "storage"."buckets" FOR EACH STATEMENT EXECUTE FUNCTION "storage"."protect_delete"();



CREATE OR REPLACE TRIGGER "protect_objects_delete" BEFORE DELETE ON "storage"."objects" FOR EACH STATEMENT EXECUTE FUNCTION "storage"."protect_delete"();



CREATE OR REPLACE TRIGGER "update_objects_updated_at" BEFORE UPDATE ON "storage"."objects" FOR EACH ROW EXECUTE FUNCTION "storage"."update_updated_at_column"();



ALTER TABLE ONLY "auth"."identities"
    ADD CONSTRAINT "identities_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "auth"."mfa_amr_claims"
    ADD CONSTRAINT "mfa_amr_claims_session_id_fkey" FOREIGN KEY ("session_id") REFERENCES "auth"."sessions"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "auth"."mfa_challenges"
    ADD CONSTRAINT "mfa_challenges_auth_factor_id_fkey" FOREIGN KEY ("factor_id") REFERENCES "auth"."mfa_factors"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "auth"."mfa_factors"
    ADD CONSTRAINT "mfa_factors_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "auth"."oauth_authorizations"
    ADD CONSTRAINT "oauth_authorizations_client_id_fkey" FOREIGN KEY ("client_id") REFERENCES "auth"."oauth_clients"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "auth"."oauth_authorizations"
    ADD CONSTRAINT "oauth_authorizations_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "auth"."oauth_consents"
    ADD CONSTRAINT "oauth_consents_client_id_fkey" FOREIGN KEY ("client_id") REFERENCES "auth"."oauth_clients"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "auth"."oauth_consents"
    ADD CONSTRAINT "oauth_consents_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "auth"."one_time_tokens"
    ADD CONSTRAINT "one_time_tokens_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "auth"."refresh_tokens"
    ADD CONSTRAINT "refresh_tokens_session_id_fkey" FOREIGN KEY ("session_id") REFERENCES "auth"."sessions"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "auth"."saml_providers"
    ADD CONSTRAINT "saml_providers_sso_provider_id_fkey" FOREIGN KEY ("sso_provider_id") REFERENCES "auth"."sso_providers"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "auth"."saml_relay_states"
    ADD CONSTRAINT "saml_relay_states_flow_state_id_fkey" FOREIGN KEY ("flow_state_id") REFERENCES "auth"."flow_state"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "auth"."saml_relay_states"
    ADD CONSTRAINT "saml_relay_states_sso_provider_id_fkey" FOREIGN KEY ("sso_provider_id") REFERENCES "auth"."sso_providers"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "auth"."sessions"
    ADD CONSTRAINT "sessions_oauth_client_id_fkey" FOREIGN KEY ("oauth_client_id") REFERENCES "auth"."oauth_clients"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "auth"."sessions"
    ADD CONSTRAINT "sessions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "auth"."sso_domains"
    ADD CONSTRAINT "sso_domains_sso_provider_id_fkey" FOREIGN KEY ("sso_provider_id") REFERENCES "auth"."sso_providers"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."ajuda"
    ADD CONSTRAINT "ajuda_usuario_id_fkey" FOREIGN KEY ("usuario_id") REFERENCES "public"."usuarios"("id");



ALTER TABLE ONLY "public"."cacl"
    ADD CONSTRAINT "cacl_filial_id_fkey" FOREIGN KEY ("filial_id") REFERENCES "public"."filiais"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."cacl"
    ADD CONSTRAINT "cacl_tanque_id_fkey" FOREIGN KEY ("tanque_id") REFERENCES "public"."tanques"("id") ON UPDATE RESTRICT ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."coletas_tanques"
    ADD CONSTRAINT "coletas_tanques_movimentacao_fkey" FOREIGN KEY ("movimentacao_id") REFERENCES "public"."movimentacoes"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."coletas_tanques"
    ADD CONSTRAINT "coletas_tanques_produto_fkey" FOREIGN KEY ("produto_id") REFERENCES "public"."produtos"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."conjuntos"
    ADD CONSTRAINT "conjuntos_cavalo_id_fkey" FOREIGN KEY ("cavalo_id") REFERENCES "public"."equipamentos"("id");



ALTER TABLE ONLY "public"."conjuntos"
    ADD CONSTRAINT "conjuntos_motorista_id_fkey" FOREIGN KEY ("motorista_id") REFERENCES "public"."motoristas"("id");



ALTER TABLE ONLY "public"."conjuntos"
    ADD CONSTRAINT "conjuntos_reboque_dois_id_fkey" FOREIGN KEY ("reboque_dois_id") REFERENCES "public"."equipamentos"("id");



ALTER TABLE ONLY "public"."conjuntos"
    ADD CONSTRAINT "conjuntos_reboque_um_id_fkey" FOREIGN KEY ("reboque_um_id") REFERENCES "public"."equipamentos"("id");



ALTER TABLE ONLY "public"."equipamentos"
    ADD CONSTRAINT "equipamentos_transportadora_id_fkey" FOREIGN KEY ("transportadora_id") REFERENCES "public"."transportadoras"("id");



ALTER TABLE ONLY "public"."movimentacoes"
    ADD CONSTRAINT "estoques_empresa_id_fkey" FOREIGN KEY ("empresa_id") REFERENCES "public"."empresas"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."movimentacoes"
    ADD CONSTRAINT "estoques_filial_id_fkey" FOREIGN KEY ("filial_id") REFERENCES "public"."filiais"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."filiais"
    ADD CONSTRAINT "filiais_empresa_id_fkey" FOREIGN KEY ("empresa_id") REFERENCES "public"."empresas"("id");



ALTER TABLE ONLY "public"."motoristas"
    ADD CONSTRAINT "motoristas_transportadora_id_fkey" FOREIGN KEY ("transportadora_id") REFERENCES "public"."transportadoras"("id");



ALTER TABLE ONLY "public"."movimentacoes"
    ADD CONSTRAINT "movimentacoes_cacl_id_fkey" FOREIGN KEY ("cacl_id") REFERENCES "public"."cacl"("id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."movimentacoes"
    ADD CONSTRAINT "movimentacoes_filial_destino_id_fkey" FOREIGN KEY ("filial_destino_id") REFERENCES "public"."filiais"("id");



ALTER TABLE ONLY "public"."movimentacoes"
    ADD CONSTRAINT "movimentacoes_filial_origem_id_fkey" FOREIGN KEY ("filial_origem_id") REFERENCES "public"."filiais"("id");



ALTER TABLE ONLY "public"."movimentacoes"
    ADD CONSTRAINT "movimentacoes_motorista_id_fkey" FOREIGN KEY ("motorista_id") REFERENCES "public"."motoristas"("id");



ALTER TABLE ONLY "public"."movimentacoes"
    ADD CONSTRAINT "movimentacoes_ordem_id_fkey" FOREIGN KEY ("ordem_id") REFERENCES "public"."ordens"("id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."movimentacoes"
    ADD CONSTRAINT "movimentacoes_produto_id_fkey1" FOREIGN KEY ("produto_id") REFERENCES "public"."produtos"("id") ON UPDATE RESTRICT ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."movimentacoes_tanque"
    ADD CONSTRAINT "movimentacoes_tanque_cacl_id_fkey" FOREIGN KEY ("cacl_id") REFERENCES "public"."cacl"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."movimentacoes_tanque"
    ADD CONSTRAINT "movimentacoes_tanque_movimentacao_fkey" FOREIGN KEY ("movimentacao_id") REFERENCES "public"."movimentacoes"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."movimentacoes_tanque"
    ADD CONSTRAINT "movimentacoes_tanque_produto_fkey" FOREIGN KEY ("produto_id") REFERENCES "public"."produtos"("id") ON UPDATE RESTRICT ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."movimentacoes_tanque"
    ADD CONSTRAINT "movimentacoes_tanque_tanque_fkey" FOREIGN KEY ("tanque_id") REFERENCES "public"."tanques"("id") ON UPDATE RESTRICT ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."movimentacoes"
    ADD CONSTRAINT "movimentacoes_transportadora_id_fkey" FOREIGN KEY ("transportadora_id") REFERENCES "public"."transportadoras"("id");



ALTER TABLE ONLY "public"."movimentacoes"
    ADD CONSTRAINT "movimentacoes_usuario_id_fkey" FOREIGN KEY ("usuario_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."ordens_analises"
    ADD CONSTRAINT "ordens_analises_filial_id_fkey" FOREIGN KEY ("filial_id") REFERENCES "public"."filiais"("id") ON UPDATE RESTRICT ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."ordens_analises"
    ADD CONSTRAINT "ordens_analises_movimentacao_id_fkey" FOREIGN KEY ("movimentacao_id") REFERENCES "public"."movimentacoes"("id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."ordens_analises"
    ADD CONSTRAINT "ordens_analises_produto_id_fkey" FOREIGN KEY ("produto_id") REFERENCES "public"."produtos"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."ordens_analises"
    ADD CONSTRAINT "ordens_analises_usuario_id_fkey" FOREIGN KEY ("usuario_id") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."percentual_mistura"
    ADD CONSTRAINT "percentual_mistura_produto_id_fkey" FOREIGN KEY ("produto_id") REFERENCES "public"."produtos"("id") ON UPDATE RESTRICT ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."permissoes"
    ADD CONSTRAINT "permissoes_id_sessao_fkey" FOREIGN KEY ("id_sessao") REFERENCES "public"."cards"("id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."permissoes"
    ADD CONSTRAINT "permissoes_id_usuario_fkey" FOREIGN KEY ("id_usuario") REFERENCES "public"."usuarios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."produtos"
    ADD CONSTRAINT "produtos_produto_dois_fkey" FOREIGN KEY ("produto_dois") REFERENCES "public"."produtos"("id");



ALTER TABLE ONLY "public"."produtos"
    ADD CONSTRAINT "produtos_produto_um_fkey" FOREIGN KEY ("produto_um") REFERENCES "public"."produtos"("id");



ALTER TABLE ONLY "public"."saldo_tanque_diario"
    ADD CONSTRAINT "saldo_tanque_diario_cacl_id_fkey" FOREIGN KEY ("cacl_id") REFERENCES "public"."cacl"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."saldo_tanque_diario"
    ADD CONSTRAINT "saldo_tanque_diario_tanque_id_fkey" FOREIGN KEY ("tanque_id") REFERENCES "public"."tanques"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."tanques"
    ADD CONSTRAINT "tanques_id_filial_fkey" FOREIGN KEY ("id_filial") REFERENCES "public"."filiais"("id") ON UPDATE RESTRICT ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."tanques"
    ADD CONSTRAINT "tanques_id_produto_fkey" FOREIGN KEY ("id_produto") REFERENCES "public"."produtos"("id") ON UPDATE RESTRICT ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."usuarios"
    ADD CONSTRAINT "usuarios_empresa_id_fkey" FOREIGN KEY ("empresa_id") REFERENCES "public"."empresas"("id") ON UPDATE RESTRICT ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."usuarios"
    ADD CONSTRAINT "usuarios_id_filial_fkey" FOREIGN KEY ("id_filial") REFERENCES "public"."filiais"("id") ON UPDATE RESTRICT ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."usuarios"
    ADD CONSTRAINT "usuarios_id_filial_segunda_fkey" FOREIGN KEY ("id_filial_segunda") REFERENCES "public"."filiais"("id") ON UPDATE RESTRICT ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."veiculos_geral"
    ADD CONSTRAINT "veiculos_geral_transportadora_id_fkey" FOREIGN KEY ("transportadora_id") REFERENCES "public"."transportadoras"("id");



ALTER TABLE ONLY "storage"."objects"
    ADD CONSTRAINT "objects_bucketId_fkey" FOREIGN KEY ("bucket_id") REFERENCES "storage"."buckets"("id");



ALTER TABLE ONLY "storage"."s3_multipart_uploads"
    ADD CONSTRAINT "s3_multipart_uploads_bucket_id_fkey" FOREIGN KEY ("bucket_id") REFERENCES "storage"."buckets"("id");



ALTER TABLE ONLY "storage"."s3_multipart_uploads_parts"
    ADD CONSTRAINT "s3_multipart_uploads_parts_bucket_id_fkey" FOREIGN KEY ("bucket_id") REFERENCES "storage"."buckets"("id");



ALTER TABLE ONLY "storage"."s3_multipart_uploads_parts"
    ADD CONSTRAINT "s3_multipart_uploads_parts_upload_id_fkey" FOREIGN KEY ("upload_id") REFERENCES "storage"."s3_multipart_uploads"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "storage"."vector_indexes"
    ADD CONSTRAINT "vector_indexes_bucket_id_fkey" FOREIGN KEY ("bucket_id") REFERENCES "storage"."buckets_vectors"("id");



ALTER TABLE "auth"."audit_log_entries" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "auth"."flow_state" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "auth"."identities" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "auth"."instances" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "auth"."mfa_amr_claims" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "auth"."mfa_challenges" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "auth"."mfa_factors" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "auth"."one_time_tokens" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "auth"."refresh_tokens" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "auth"."saml_providers" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "auth"."saml_relay_states" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "auth"."schema_migrations" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "auth"."sessions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "auth"."sso_domains" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "auth"."sso_providers" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "auth"."users" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "Acesso total para autenticados" ON "public"."permissoes" TO "authenticated" USING (true) WITH CHECK (true);



CREATE POLICY "Acesso total para nível 3, restrito por filial para os demais" ON "public"."tanques" USING (((( SELECT "usuarios"."nivel"
   FROM "public"."usuarios"
  WHERE ("usuarios"."id" = "auth"."uid"())) = 3) OR ("id_filial" = ( SELECT "usuarios"."id_filial"
   FROM "public"."usuarios"
  WHERE ("usuarios"."id" = "auth"."uid"()))))) WITH CHECK (((( SELECT "usuarios"."nivel"
   FROM "public"."usuarios"
  WHERE ("usuarios"."id" = "auth"."uid"())) = 3) OR ("id_filial" = ( SELECT "usuarios"."id_filial"
   FROM "public"."usuarios"
  WHERE ("usuarios"."id" = "auth"."uid"())))));



CREATE POLICY "Leitura para usuários logados" ON "public"."empresas" FOR SELECT USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "Permitir CRUD completo para usuários autenticados" ON "public"."transportadoras" TO "authenticated" USING (true) WITH CHECK (true);



CREATE POLICY "Permitir CRUD para usuários autenticados" ON "public"."cards" TO "authenticated" USING (true) WITH CHECK (true);



CREATE POLICY "Permitir CRUD para usuários autenticados" ON "public"."equipamentos" TO "authenticated" USING (true) WITH CHECK (true);



CREATE POLICY "Permitir CRUD para usuários autenticados" ON "public"."veiculos_geral" TO "authenticated" USING (true) WITH CHECK (true);



CREATE POLICY "Permitir CRUD para usuários logados" ON "public"."conjuntos" TO "authenticated" USING (true) WITH CHECK (true);



CREATE POLICY "Permitir CRUD para usuários logados" ON "public"."motoristas" TO "authenticated" USING (true) WITH CHECK (true);



CREATE POLICY "Permitir DELETE na mesma filial" ON "public"."tanques" FOR DELETE USING (("id_filial" = ( SELECT "usuarios"."id_filial"
   FROM "public"."usuarios"
  WHERE ("usuarios"."id" = "auth"."uid"()))));



CREATE POLICY "Permitir DELETE para usuários autenticados" ON "public"."movimentacoes" FOR DELETE TO "authenticated" USING (true);



CREATE POLICY "Permitir INSERT na mesma filial" ON "public"."tanques" FOR INSERT WITH CHECK (("id_filial" = ( SELECT "usuarios"."id_filial"
   FROM "public"."usuarios"
  WHERE ("usuarios"."id" = "auth"."uid"()))));



CREATE POLICY "Permitir INSERT para usuários autenticados" ON "public"."movimentacoes" FOR INSERT TO "authenticated" WITH CHECK (true);



CREATE POLICY "Permitir SELECT para usuários autenticados" ON "public"."movimentacoes" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Permitir UPDATE na mesma filial" ON "public"."tanques" FOR UPDATE USING (("id_filial" = ( SELECT "usuarios"."id_filial"
   FROM "public"."usuarios"
  WHERE ("usuarios"."id" = "auth"."uid"())))) WITH CHECK (("id_filial" = ( SELECT "usuarios"."id_filial"
   FROM "public"."usuarios"
  WHERE ("usuarios"."id" = "auth"."uid"()))));



CREATE POLICY "Permitir UPDATE para usuários autenticados" ON "public"."movimentacoes" FOR UPDATE TO "authenticated" USING (true) WITH CHECK (true);



CREATE POLICY "Permitir leitura de id_filial do próprio usuário" ON "public"."usuarios" FOR SELECT USING (("auth"."uid"() = "id"));



CREATE POLICY "Permitir leitura para autenticados" ON "public"."arqueacao_janauba" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Permitir leitura para autenticados" ON "public"."arqueacao_jequie" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Qualquer usuário logado pode atualizar" ON "public"."ajuda" FOR UPDATE TO "authenticated" USING (true) WITH CHECK (true);



CREATE POLICY "Qualquer usuário logado pode deletar" ON "public"."ajuda" FOR DELETE TO "authenticated" USING (true);



CREATE POLICY "Qualquer usuário logado pode inserir" ON "public"."ajuda" FOR INSERT TO "authenticated" WITH CHECK (true);



CREATE POLICY "Qualquer usuário logado pode ler" ON "public"."ajuda" FOR SELECT TO "authenticated" USING (true);



ALTER TABLE "public"."TCD_anidro_hidratado" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."TCD_gasolina_diesel" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."TCV_anidro_hidratado" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."TCV_gasolina_diesel" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "Usuários autenticados podem atualizar cacl" ON "public"."cacl" FOR UPDATE TO "authenticated" USING (true);



CREATE POLICY "Usuários autenticados podem deletar cacl" ON "public"."cacl" FOR DELETE TO "authenticated" USING (true);



CREATE POLICY "Usuários autenticados podem inserir cacl" ON "public"."cacl" FOR INSERT TO "authenticated" WITH CHECK (true);



CREATE POLICY "Usuários autenticados podem ler cacl" ON "public"."cacl" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Usuários podem atualizar suas próprias ordens" ON "public"."ordens_analises" FOR UPDATE USING (("auth"."uid"() = "usuario_id"));



CREATE POLICY "Usuários podem inserir suas próprias ordens" ON "public"."ordens_analises" FOR INSERT WITH CHECK (("auth"."uid"() = "usuario_id"));



CREATE POLICY "Usuários podem ver suas próprias ordens" ON "public"."ordens_analises" FOR SELECT USING (("auth"."uid"() = "usuario_id"));



ALTER TABLE "public"."ajuda" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."arqueacao_janauba" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."arqueacao_jequie" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."cacl" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."cadastros_pendentes" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."cards" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."coletas_tanques" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "coletas_tanques_delete_authenticated" ON "public"."coletas_tanques" FOR DELETE TO "authenticated" USING (true);



CREATE POLICY "coletas_tanques_insert_authenticated" ON "public"."coletas_tanques" FOR INSERT TO "authenticated" WITH CHECK (true);



CREATE POLICY "coletas_tanques_select_authenticated" ON "public"."coletas_tanques" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "coletas_tanques_update_authenticated" ON "public"."coletas_tanques" FOR UPDATE TO "authenticated" USING (true) WITH CHECK (true);



ALTER TABLE "public"."conjuntos" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."empresas" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."equipamentos" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."filiais" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."motoristas" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."movimentacoes" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."movimentacoes_tanque" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "movimentacoes_tanque_delete_all_logged" ON "public"."movimentacoes_tanque" FOR DELETE TO "authenticated" USING (true);



CREATE POLICY "movimentacoes_tanque_insert_all_logged" ON "public"."movimentacoes_tanque" FOR INSERT TO "authenticated" WITH CHECK (true);



CREATE POLICY "movimentacoes_tanque_select_all_logged" ON "public"."movimentacoes_tanque" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "movimentacoes_tanque_update_all_logged" ON "public"."movimentacoes_tanque" FOR UPDATE TO "authenticated" USING (true) WITH CHECK (true);



ALTER TABLE "public"."ordens" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."ordens_analises" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "ordens_delete_any_logged" ON "public"."ordens" FOR DELETE USING (("auth"."uid"() IS NOT NULL));



CREATE POLICY "ordens_insert_any_logged" ON "public"."ordens" FOR INSERT WITH CHECK (("auth"."uid"() IS NOT NULL));



CREATE POLICY "ordens_select_any_logged" ON "public"."ordens" FOR SELECT USING (("auth"."uid"() IS NOT NULL));



CREATE POLICY "ordens_update_any_logged" ON "public"."ordens" FOR UPDATE USING (("auth"."uid"() IS NOT NULL)) WITH CHECK (("auth"."uid"() IS NOT NULL));



CREATE POLICY "p_leitura_geral" ON "public"."produtos" FOR SELECT USING (true);



CREATE POLICY "p_nivel_3_crud" ON "public"."produtos" USING (("current_setting"('app.nivel_usuario'::"text", true) = '3'::"text")) WITH CHECK (("current_setting"('app.nivel_usuario'::"text", true) = '3'::"text"));



ALTER TABLE "public"."percentual_mistura" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "percentual_mistura_delete_all_logged" ON "public"."percentual_mistura" FOR DELETE TO "authenticated" USING (true);



CREATE POLICY "percentual_mistura_insert_all_logged" ON "public"."percentual_mistura" FOR INSERT TO "authenticated" WITH CHECK (true);



CREATE POLICY "percentual_mistura_select_all_logged" ON "public"."percentual_mistura" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "percentual_mistura_update_all_logged" ON "public"."percentual_mistura" FOR UPDATE TO "authenticated" USING (true) WITH CHECK (true);



ALTER TABLE "public"."permissoes" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "permitir_atualizar_todos" ON "public"."cadastros_pendentes" FOR UPDATE TO "authenticated" USING (true) WITH CHECK (true);



CREATE POLICY "permitir_excluir_todos" ON "public"."cadastros_pendentes" FOR DELETE TO "authenticated" USING (true);



CREATE POLICY "permitir_inserir_todos" ON "public"."cadastros_pendentes" FOR INSERT TO "authenticated" WITH CHECK (true);



CREATE POLICY "permitir_leitura_todos" ON "public"."cadastros_pendentes" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "permitir_leitura_todos" ON "public"."filiais" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "permitir_leitura_todos" ON "public"."usuarios" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "permitir_update_redefinicao_senha_sem_login" ON "public"."usuarios" FOR UPDATE USING (true) WITH CHECK (("redefinicao_senha" IS NOT NULL));



ALTER TABLE "public"."produtos" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "publico_pode_atualizar" ON "public"."cadastros_pendentes" FOR UPDATE USING (true) WITH CHECK (true);



CREATE POLICY "publico_pode_excluir" ON "public"."cadastros_pendentes" FOR DELETE USING (true);



CREATE POLICY "publico_pode_inserir" ON "public"."cadastros_pendentes" FOR INSERT WITH CHECK (true);



CREATE POLICY "publico_pode_ler" ON "public"."cadastros_pendentes" FOR SELECT USING (true);



CREATE POLICY "publico_pode_ler_filiais" ON "public"."filiais" FOR SELECT USING (true);



ALTER TABLE "public"."saldo_tanque_diario" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "saldo_tanque_diario_delete_auth" ON "public"."saldo_tanque_diario" FOR DELETE TO "authenticated" USING (true);



CREATE POLICY "saldo_tanque_diario_insert_auth" ON "public"."saldo_tanque_diario" FOR INSERT TO "authenticated" WITH CHECK (true);



CREATE POLICY "saldo_tanque_diario_select_auth" ON "public"."saldo_tanque_diario" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "saldo_tanque_diario_update_auth" ON "public"."saldo_tanque_diario" FOR UPDATE TO "authenticated" USING (true) WITH CHECK (true);



ALTER TABLE "public"."tanques" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "tcd_anidro_select" ON "public"."TCD_anidro_hidratado" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "tcd_gasolina_select" ON "public"."TCD_gasolina_diesel" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "tcv_anidro_select" ON "public"."TCV_anidro_hidratado" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "tcv_gasolina_select" ON "public"."TCV_gasolina_diesel" FOR SELECT TO "authenticated" USING (true);



ALTER TABLE "public"."transportadoras" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."usuarios" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "usuarios_nivel3_delete" ON "public"."usuarios" FOR DELETE USING ("public"."usuario_nivel3"());



CREATE POLICY "usuarios_nivel3_insert" ON "public"."usuarios" FOR INSERT WITH CHECK ("public"."usuario_nivel3"());



CREATE POLICY "usuarios_nivel3_select" ON "public"."usuarios" FOR SELECT USING ("public"."usuario_nivel3"());



CREATE POLICY "usuarios_nivel3_update" ON "public"."usuarios" FOR UPDATE USING ("public"."usuario_nivel3"()) WITH CHECK (true);



ALTER TABLE "public"."veiculos_geral" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "storage"."buckets" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "storage"."buckets_analytics" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "storage"."buckets_vectors" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "storage"."migrations" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "storage"."objects" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "storage"."s3_multipart_uploads" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "storage"."s3_multipart_uploads_parts" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "storage"."vector_indexes" ENABLE ROW LEVEL SECURITY;


GRANT USAGE ON SCHEMA "auth" TO "anon";
GRANT USAGE ON SCHEMA "auth" TO "authenticated";
GRANT USAGE ON SCHEMA "auth" TO "service_role";
GRANT ALL ON SCHEMA "auth" TO "supabase_auth_admin";
GRANT ALL ON SCHEMA "auth" TO "dashboard_user";
GRANT USAGE ON SCHEMA "auth" TO "postgres";



GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";



GRANT USAGE ON SCHEMA "storage" TO "postgres" WITH GRANT OPTION;
GRANT USAGE ON SCHEMA "storage" TO "anon";
GRANT USAGE ON SCHEMA "storage" TO "authenticated";
GRANT USAGE ON SCHEMA "storage" TO "service_role";
GRANT ALL ON SCHEMA "storage" TO "supabase_storage_admin";
GRANT ALL ON SCHEMA "storage" TO "dashboard_user";



GRANT ALL ON FUNCTION "auth"."email"() TO "dashboard_user";



GRANT ALL ON FUNCTION "auth"."jwt"() TO "postgres";
GRANT ALL ON FUNCTION "auth"."jwt"() TO "dashboard_user";



GRANT ALL ON FUNCTION "auth"."role"() TO "dashboard_user";



GRANT ALL ON FUNCTION "auth"."uid"() TO "dashboard_user";



GRANT ALL ON FUNCTION "public"."alimentar_movim_tanque_transf"() TO "anon";
GRANT ALL ON FUNCTION "public"."alimentar_movim_tanque_transf"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."alimentar_movim_tanque_transf"() TO "service_role";



GRANT ALL ON FUNCTION "public"."alimentar_saldo_tanque_diario"() TO "anon";
GRANT ALL ON FUNCTION "public"."alimentar_saldo_tanque_diario"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."alimentar_saldo_tanque_diario"() TO "service_role";



GRANT ALL ON FUNCTION "public"."atualizar_timestamp"() TO "anon";
GRANT ALL ON FUNCTION "public"."atualizar_timestamp"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."atualizar_timestamp"() TO "service_role";



GRANT ALL ON FUNCTION "public"."buscar_volume_tabela"("schema_nome" "text", "tabela_nome" "text", "coluna_cm" "text", "coluna_mm" "text", "altura_cm" integer, "altura_mm" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."buscar_volume_tabela"("schema_nome" "text", "tabela_nome" "text", "coluna_cm" "text", "coluna_mm" "text", "altura_cm" integer, "altura_mm" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."buscar_volume_tabela"("schema_nome" "text", "tabela_nome" "text", "coluna_cm" "text", "coluna_mm" "text", "altura_cm" integer, "altura_mm" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."buscar_volume_tabela_debug_json"("schema_nome" "text", "tabela_nome" "text", "coluna_cm" "text", "coluna_mm" "text", "altura_cm" integer, "altura_mm" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."buscar_volume_tabela_debug_json"("schema_nome" "text", "tabela_nome" "text", "coluna_cm" "text", "coluna_mm" "text", "altura_cm" integer, "altura_mm" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."buscar_volume_tabela_debug_json"("schema_nome" "text", "tabela_nome" "text", "coluna_cm" "text", "coluna_mm" "text", "altura_cm" integer, "altura_mm" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."definir_tanque_venda_func"() TO "anon";
GRANT ALL ON FUNCTION "public"."definir_tanque_venda_func"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."definir_tanque_venda_func"() TO "service_role";



GRANT ALL ON FUNCTION "public"."excluir_usuario_por_email"("email_input" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."excluir_usuario_por_email"("email_input" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."excluir_usuario_por_email"("email_input" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."fn_estoque_inicial_tanque"("p_tanque_id" "uuid", "p_data" "date") TO "anon";
GRANT ALL ON FUNCTION "public"."fn_estoque_inicial_tanque"("p_tanque_id" "uuid", "p_data" "date") TO "authenticated";
GRANT ALL ON FUNCTION "public"."fn_estoque_inicial_tanque"("p_tanque_id" "uuid", "p_data" "date") TO "service_role";



GRANT ALL ON FUNCTION "public"."fn_gerar_movimentacao_tanque"() TO "anon";
GRANT ALL ON FUNCTION "public"."fn_gerar_movimentacao_tanque"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."fn_gerar_movimentacao_tanque"() TO "service_role";



GRANT ALL ON FUNCTION "public"."fn_gerar_movimentacao_tanque_v2"() TO "anon";
GRANT ALL ON FUNCTION "public"."fn_gerar_movimentacao_tanque_v2"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."fn_gerar_movimentacao_tanque_v2"() TO "service_role";



GRANT ALL ON FUNCTION "public"."gerar_movimentacoes_tanque_func"() TO "anon";
GRANT ALL ON FUNCTION "public"."gerar_movimentacoes_tanque_func"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."gerar_movimentacoes_tanque_func"() TO "service_role";



GRANT ALL ON FUNCTION "public"."gerar_numero_controle"() TO "anon";
GRANT ALL ON FUNCTION "public"."gerar_numero_controle"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."gerar_numero_controle"() TO "service_role";



GRANT ALL ON FUNCTION "public"."test_trigger_simples"() TO "anon";
GRANT ALL ON FUNCTION "public"."test_trigger_simples"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."test_trigger_simples"() TO "service_role";



GRANT ALL ON FUNCTION "public"."trigger_inserir_saldo_tanque_diario"() TO "anon";
GRANT ALL ON FUNCTION "public"."trigger_inserir_saldo_tanque_diario"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."trigger_inserir_saldo_tanque_diario"() TO "service_role";



GRANT ALL ON FUNCTION "public"."trigger_movimentacoes_tanque"() TO "anon";
GRANT ALL ON FUNCTION "public"."trigger_movimentacoes_tanque"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."trigger_movimentacoes_tanque"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_atualizado_em"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_atualizado_em"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_atualizado_em"() TO "service_role";



GRANT ALL ON FUNCTION "public"."usuario_nivel3"() TO "anon";
GRANT ALL ON FUNCTION "public"."usuario_nivel3"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."usuario_nivel3"() TO "service_role";



GRANT ALL ON TABLE "auth"."audit_log_entries" TO "dashboard_user";
GRANT INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE "auth"."audit_log_entries" TO "postgres";
GRANT SELECT ON TABLE "auth"."audit_log_entries" TO "postgres" WITH GRANT OPTION;



GRANT INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE "auth"."flow_state" TO "postgres";
GRANT SELECT ON TABLE "auth"."flow_state" TO "postgres" WITH GRANT OPTION;
GRANT ALL ON TABLE "auth"."flow_state" TO "dashboard_user";



GRANT INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE "auth"."identities" TO "postgres";
GRANT SELECT ON TABLE "auth"."identities" TO "postgres" WITH GRANT OPTION;
GRANT ALL ON TABLE "auth"."identities" TO "dashboard_user";



GRANT ALL ON TABLE "auth"."instances" TO "dashboard_user";
GRANT INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE "auth"."instances" TO "postgres";
GRANT SELECT ON TABLE "auth"."instances" TO "postgres" WITH GRANT OPTION;



GRANT INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE "auth"."mfa_amr_claims" TO "postgres";
GRANT SELECT ON TABLE "auth"."mfa_amr_claims" TO "postgres" WITH GRANT OPTION;
GRANT ALL ON TABLE "auth"."mfa_amr_claims" TO "dashboard_user";



GRANT INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE "auth"."mfa_challenges" TO "postgres";
GRANT SELECT ON TABLE "auth"."mfa_challenges" TO "postgres" WITH GRANT OPTION;
GRANT ALL ON TABLE "auth"."mfa_challenges" TO "dashboard_user";



GRANT INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE "auth"."mfa_factors" TO "postgres";
GRANT SELECT ON TABLE "auth"."mfa_factors" TO "postgres" WITH GRANT OPTION;
GRANT ALL ON TABLE "auth"."mfa_factors" TO "dashboard_user";



GRANT ALL ON TABLE "auth"."oauth_authorizations" TO "postgres";
GRANT ALL ON TABLE "auth"."oauth_authorizations" TO "dashboard_user";



GRANT ALL ON TABLE "auth"."oauth_client_states" TO "postgres";
GRANT ALL ON TABLE "auth"."oauth_client_states" TO "dashboard_user";



GRANT ALL ON TABLE "auth"."oauth_clients" TO "postgres";
GRANT ALL ON TABLE "auth"."oauth_clients" TO "dashboard_user";



GRANT ALL ON TABLE "auth"."oauth_consents" TO "postgres";
GRANT ALL ON TABLE "auth"."oauth_consents" TO "dashboard_user";



GRANT INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE "auth"."one_time_tokens" TO "postgres";
GRANT SELECT ON TABLE "auth"."one_time_tokens" TO "postgres" WITH GRANT OPTION;
GRANT ALL ON TABLE "auth"."one_time_tokens" TO "dashboard_user";



GRANT ALL ON TABLE "auth"."refresh_tokens" TO "dashboard_user";
GRANT INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE "auth"."refresh_tokens" TO "postgres";
GRANT SELECT ON TABLE "auth"."refresh_tokens" TO "postgres" WITH GRANT OPTION;



GRANT ALL ON SEQUENCE "auth"."refresh_tokens_id_seq" TO "dashboard_user";
GRANT ALL ON SEQUENCE "auth"."refresh_tokens_id_seq" TO "postgres";



GRANT INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE "auth"."saml_providers" TO "postgres";
GRANT SELECT ON TABLE "auth"."saml_providers" TO "postgres" WITH GRANT OPTION;
GRANT ALL ON TABLE "auth"."saml_providers" TO "dashboard_user";



GRANT INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE "auth"."saml_relay_states" TO "postgres";
GRANT SELECT ON TABLE "auth"."saml_relay_states" TO "postgres" WITH GRANT OPTION;
GRANT ALL ON TABLE "auth"."saml_relay_states" TO "dashboard_user";



GRANT SELECT ON TABLE "auth"."schema_migrations" TO "postgres" WITH GRANT OPTION;



GRANT INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE "auth"."sessions" TO "postgres";
GRANT SELECT ON TABLE "auth"."sessions" TO "postgres" WITH GRANT OPTION;
GRANT ALL ON TABLE "auth"."sessions" TO "dashboard_user";



GRANT INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE "auth"."sso_domains" TO "postgres";
GRANT SELECT ON TABLE "auth"."sso_domains" TO "postgres" WITH GRANT OPTION;
GRANT ALL ON TABLE "auth"."sso_domains" TO "dashboard_user";



GRANT INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE "auth"."sso_providers" TO "postgres";
GRANT SELECT ON TABLE "auth"."sso_providers" TO "postgres" WITH GRANT OPTION;
GRANT ALL ON TABLE "auth"."sso_providers" TO "dashboard_user";



GRANT ALL ON TABLE "auth"."users" TO "dashboard_user";
GRANT INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE "auth"."users" TO "postgres";
GRANT SELECT ON TABLE "auth"."users" TO "postgres" WITH GRANT OPTION;



GRANT ALL ON TABLE "public"."TCD_anidro_hidratado" TO "anon";
GRANT ALL ON TABLE "public"."TCD_anidro_hidratado" TO "authenticated";
GRANT ALL ON TABLE "public"."TCD_anidro_hidratado" TO "service_role";



GRANT ALL ON TABLE "public"."TCD_gasolina_diesel" TO "anon";
GRANT ALL ON TABLE "public"."TCD_gasolina_diesel" TO "authenticated";
GRANT ALL ON TABLE "public"."TCD_gasolina_diesel" TO "service_role";



GRANT ALL ON TABLE "public"."TCV_anidro_hidratado" TO "anon";
GRANT ALL ON TABLE "public"."TCV_anidro_hidratado" TO "authenticated";
GRANT ALL ON TABLE "public"."TCV_anidro_hidratado" TO "service_role";



GRANT ALL ON TABLE "public"."TCV_gasolina_diesel" TO "anon";
GRANT ALL ON TABLE "public"."TCV_gasolina_diesel" TO "authenticated";
GRANT ALL ON TABLE "public"."TCV_gasolina_diesel" TO "service_role";



GRANT ALL ON TABLE "public"."ajuda" TO "anon";
GRANT ALL ON TABLE "public"."ajuda" TO "authenticated";
GRANT ALL ON TABLE "public"."ajuda" TO "service_role";



GRANT SELECT ON TABLE "public"."arqueacao_janauba" TO "authenticated";



GRANT ALL ON TABLE "public"."arqueacao_jequie" TO "anon";
GRANT ALL ON TABLE "public"."arqueacao_jequie" TO "authenticated";
GRANT ALL ON TABLE "public"."arqueacao_jequie" TO "service_role";



GRANT ALL ON TABLE "public"."cacl" TO "anon";
GRANT ALL ON TABLE "public"."cacl" TO "authenticated";
GRANT ALL ON TABLE "public"."cacl" TO "service_role";



GRANT ALL ON TABLE "public"."cadastros_pendentes" TO "anon";
GRANT ALL ON TABLE "public"."cadastros_pendentes" TO "authenticated";
GRANT ALL ON TABLE "public"."cadastros_pendentes" TO "service_role";



GRANT ALL ON TABLE "public"."cards" TO "anon";
GRANT ALL ON TABLE "public"."cards" TO "authenticated";
GRANT ALL ON TABLE "public"."cards" TO "service_role";



GRANT ALL ON TABLE "public"."coletas_tanques" TO "anon";
GRANT ALL ON TABLE "public"."coletas_tanques" TO "authenticated";
GRANT ALL ON TABLE "public"."coletas_tanques" TO "service_role";



GRANT ALL ON TABLE "public"."conjuntos" TO "anon";
GRANT ALL ON TABLE "public"."conjuntos" TO "authenticated";
GRANT ALL ON TABLE "public"."conjuntos" TO "service_role";



GRANT ALL ON TABLE "public"."empresas" TO "anon";
GRANT ALL ON TABLE "public"."empresas" TO "authenticated";
GRANT ALL ON TABLE "public"."empresas" TO "service_role";



GRANT ALL ON TABLE "public"."equipamentos" TO "anon";
GRANT ALL ON TABLE "public"."equipamentos" TO "authenticated";
GRANT ALL ON TABLE "public"."equipamentos" TO "service_role";



GRANT ALL ON TABLE "public"."filiais" TO "anon";
GRANT ALL ON TABLE "public"."filiais" TO "authenticated";
GRANT ALL ON TABLE "public"."filiais" TO "service_role";



GRANT ALL ON TABLE "public"."motoristas" TO "anon";
GRANT ALL ON TABLE "public"."motoristas" TO "authenticated";
GRANT ALL ON TABLE "public"."motoristas" TO "service_role";



GRANT ALL ON TABLE "public"."movimentacoes" TO "anon";
GRANT ALL ON TABLE "public"."movimentacoes" TO "authenticated";
GRANT ALL ON TABLE "public"."movimentacoes" TO "service_role";



GRANT ALL ON TABLE "public"."movimentacoes_tanque" TO "anon";
GRANT ALL ON TABLE "public"."movimentacoes_tanque" TO "authenticated";
GRANT ALL ON TABLE "public"."movimentacoes_tanque" TO "service_role";



GRANT ALL ON TABLE "public"."ordens" TO "anon";
GRANT ALL ON TABLE "public"."ordens" TO "authenticated";
GRANT ALL ON TABLE "public"."ordens" TO "service_role";



GRANT ALL ON TABLE "public"."ordens_analises" TO "anon";
GRANT ALL ON TABLE "public"."ordens_analises" TO "authenticated";
GRANT ALL ON TABLE "public"."ordens_analises" TO "service_role";



GRANT ALL ON TABLE "public"."percentual_mistura" TO "anon";
GRANT ALL ON TABLE "public"."percentual_mistura" TO "authenticated";
GRANT ALL ON TABLE "public"."percentual_mistura" TO "service_role";



GRANT ALL ON TABLE "public"."permissoes" TO "anon";
GRANT ALL ON TABLE "public"."permissoes" TO "authenticated";
GRANT ALL ON TABLE "public"."permissoes" TO "service_role";



GRANT ALL ON TABLE "public"."produtos" TO "anon";
GRANT ALL ON TABLE "public"."produtos" TO "authenticated";
GRANT ALL ON TABLE "public"."produtos" TO "service_role";



GRANT ALL ON SEQUENCE "public"."produtos_new_codigo_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."produtos_new_codigo_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."produtos_new_codigo_seq" TO "service_role";



GRANT ALL ON TABLE "public"."saldo_tanque_diario" TO "anon";
GRANT ALL ON TABLE "public"."saldo_tanque_diario" TO "authenticated";
GRANT ALL ON TABLE "public"."saldo_tanque_diario" TO "service_role";



GRANT ALL ON TABLE "public"."tanques" TO "anon";
GRANT ALL ON TABLE "public"."tanques" TO "authenticated";
GRANT ALL ON TABLE "public"."tanques" TO "service_role";



GRANT ALL ON TABLE "public"."tcd_anidro_hidratado_vw" TO "anon";
GRANT ALL ON TABLE "public"."tcd_anidro_hidratado_vw" TO "authenticated";
GRANT ALL ON TABLE "public"."tcd_anidro_hidratado_vw" TO "service_role";



GRANT ALL ON TABLE "public"."tcd_gasolina_diesel_vw" TO "anon";
GRANT ALL ON TABLE "public"."tcd_gasolina_diesel_vw" TO "authenticated";
GRANT ALL ON TABLE "public"."tcd_gasolina_diesel_vw" TO "service_role";



GRANT ALL ON TABLE "public"."tcv_anidro_hidratado_vw" TO "anon";
GRANT ALL ON TABLE "public"."tcv_anidro_hidratado_vw" TO "authenticated";
GRANT ALL ON TABLE "public"."tcv_anidro_hidratado_vw" TO "service_role";



GRANT ALL ON TABLE "public"."tcv_gasolina_diesel_vw" TO "anon";
GRANT ALL ON TABLE "public"."tcv_gasolina_diesel_vw" TO "authenticated";
GRANT ALL ON TABLE "public"."tcv_gasolina_diesel_vw" TO "service_role";



GRANT ALL ON TABLE "public"."transportadoras" TO "anon";
GRANT ALL ON TABLE "public"."transportadoras" TO "authenticated";
GRANT ALL ON TABLE "public"."transportadoras" TO "service_role";



GRANT ALL ON TABLE "public"."usuarios" TO "anon";
GRANT ALL ON TABLE "public"."usuarios" TO "authenticated";
GRANT ALL ON TABLE "public"."usuarios" TO "service_role";



GRANT UPDATE("redefinicao_senha") ON TABLE "public"."usuarios" TO PUBLIC;



GRANT ALL ON TABLE "public"."veiculos_geral" TO "anon";
GRANT ALL ON TABLE "public"."veiculos_geral" TO "authenticated";
GRANT ALL ON TABLE "public"."veiculos_geral" TO "service_role";



GRANT ALL ON TABLE "public"."view_placas_distintas" TO "anon";
GRANT ALL ON TABLE "public"."view_placas_distintas" TO "authenticated";
GRANT ALL ON TABLE "public"."view_placas_distintas" TO "service_role";



GRANT ALL ON TABLE "public"."view_placas_tanques" TO "anon";
GRANT ALL ON TABLE "public"."view_placas_tanques" TO "authenticated";
GRANT ALL ON TABLE "public"."view_placas_tanques" TO "service_role";



REVOKE ALL ON TABLE "storage"."buckets" FROM "supabase_storage_admin";
GRANT ALL ON TABLE "storage"."buckets" TO "supabase_storage_admin" WITH GRANT OPTION;
GRANT ALL ON TABLE "storage"."buckets" TO "anon";
GRANT ALL ON TABLE "storage"."buckets" TO "authenticated";
GRANT ALL ON TABLE "storage"."buckets" TO "service_role";
GRANT ALL ON TABLE "storage"."buckets" TO "postgres" WITH GRANT OPTION;



GRANT ALL ON TABLE "storage"."buckets_analytics" TO "service_role";
GRANT ALL ON TABLE "storage"."buckets_analytics" TO "authenticated";
GRANT ALL ON TABLE "storage"."buckets_analytics" TO "anon";



GRANT SELECT ON TABLE "storage"."buckets_vectors" TO "service_role";
GRANT SELECT ON TABLE "storage"."buckets_vectors" TO "authenticated";
GRANT SELECT ON TABLE "storage"."buckets_vectors" TO "anon";



REVOKE ALL ON TABLE "storage"."objects" FROM "supabase_storage_admin";
GRANT ALL ON TABLE "storage"."objects" TO "supabase_storage_admin" WITH GRANT OPTION;
GRANT ALL ON TABLE "storage"."objects" TO "anon";
GRANT ALL ON TABLE "storage"."objects" TO "authenticated";
GRANT ALL ON TABLE "storage"."objects" TO "service_role";
GRANT ALL ON TABLE "storage"."objects" TO "postgres" WITH GRANT OPTION;



GRANT ALL ON TABLE "storage"."s3_multipart_uploads" TO "service_role";
GRANT SELECT ON TABLE "storage"."s3_multipart_uploads" TO "authenticated";
GRANT SELECT ON TABLE "storage"."s3_multipart_uploads" TO "anon";



GRANT ALL ON TABLE "storage"."s3_multipart_uploads_parts" TO "service_role";
GRANT SELECT ON TABLE "storage"."s3_multipart_uploads_parts" TO "authenticated";
GRANT SELECT ON TABLE "storage"."s3_multipart_uploads_parts" TO "anon";



GRANT SELECT ON TABLE "storage"."vector_indexes" TO "service_role";
GRANT SELECT ON TABLE "storage"."vector_indexes" TO "authenticated";
GRANT SELECT ON TABLE "storage"."vector_indexes" TO "anon";



ALTER DEFAULT PRIVILEGES FOR ROLE "supabase_auth_admin" IN SCHEMA "auth" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "supabase_auth_admin" IN SCHEMA "auth" GRANT ALL ON SEQUENCES TO "dashboard_user";



ALTER DEFAULT PRIVILEGES FOR ROLE "supabase_auth_admin" IN SCHEMA "auth" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "supabase_auth_admin" IN SCHEMA "auth" GRANT ALL ON FUNCTIONS TO "dashboard_user";



ALTER DEFAULT PRIVILEGES FOR ROLE "supabase_auth_admin" IN SCHEMA "auth" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "supabase_auth_admin" IN SCHEMA "auth" GRANT ALL ON TABLES TO "dashboard_user";



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






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "storage" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "storage" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "storage" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "storage" GRANT ALL ON SEQUENCES TO "service_role";



ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "storage" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "storage" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "storage" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "storage" GRANT ALL ON FUNCTIONS TO "service_role";



ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "storage" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "storage" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "storage" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "storage" GRANT ALL ON TABLES TO "service_role";




