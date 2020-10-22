-- [R144917][AL01] Maiores devedores BNDT - feito a partir do N997
select
    tmp.nr_documento_identificacao as "CPF/CNPJ",
    tmp.ds_nome as "Nome da Pessoa"
    , COUNT(tmp.nr_documento_identificacao) as "Quantidade de Processos"
    , '$URL/execucao/N997?NOME_PARTE_OBRIG='||tmp.ds_nome
          ||'&DOC_IDENTIFICACAO='||regexp_replace(tmp.nr_documento_identificacao,'[.\\/-]','','g')
          ||'&DATA_INICIAL='||to_char(coalesce(:DATA_INICIAL, date_trunc('year', current_date))::date,'mm/dd/yyyy')
          ||'&DATA_FINAL='||to_char(coalesce(:DATA_OPCIONAL_FINAL, current_date)::date,'mm/dd/yyyy')
          ||CASE
              WHEN :ORGAO_JULGADOR_TODOS IS NULL
                  THEN ''
              ELSE '&ORGAO_JULGADOR='||:ORGAO_JULGADOR_TODOS
              END
          ||CASE
              WHEN :ID_SITUACAO_DEB_TRAB IS NULL
                  THEN ''
              ELSE '&ID_SITUACAO_DEB_TRAB='||:ID_SITUACAO_DEB_TRAB
              END
        AS "PROCESSOS REGISTRADOS NO BNDT VIA PJe 1º GRAU"
    , to_char(coalesce(:DATA_INICIAL, date_trunc('year', current_date))::date,'dd/mm/yyyy') AS "Data inicial do
relatório"
    , to_char(coalesce(:DATA_OPCIONAL_FINAL, current_date)::date,'dd/mm/yyyy') AS "Data final do relatório"
  from (
    select
        proc.id_processo,
        proc.nr_processo,
        ul.ds_nome,
        sdt.ds_descricao as ds_situacao_sucesso,
        sdt.id_situacao_debito_trabalhista as id_situacao_debito_trabalhista_sucesso,
        sdt_ultimo_envio.ds_descricao as ds_situacao_ult_envio,
        pdi.nr_documento_identificacao,
        CASE
      WHEN dt.in_sincronizacao = 'S' THEN 'Sim'
      WHEN dt.in_sincronizacao IS NULL THEN 'Sim'
      ELSE 'Não'
        END sincronizado,
        dth.id_debto_trabalhista_historico,
        dth.dt_envio,
        dth.id_usuario,
        -- ordena registros do histórico de um débito por data de envio. Na consulta externa iremos selecionar o registor mais recente
        rank() over (partition by dt.id_debito_trabalhista, dth.id_processo_parte order by dth.dt_envio desc) linha_dth,
        coalesce(desloc.id_oj_destino, dist.id_orgao_julgador, ptrf.id_orgao_julgador) as id_orgao_julgador,
        --desloc.dt_deslocamento,
        -- ordena registros do histórico de deslocamento por data do deslocamento. Na consulta externa iremos selecionar o deslocamento mais recente
        rank() over (partition by dt.id_debito_trabalhista, desloc.id_processo_trf order by desloc.dt_deslocamento desc) linha_desloc,
        dist.dt_log,
        -- ordena registros do log de distribuição por data da distribuição. Na consulta externa iremos selecionar a distribuição mais recente
        rank() over (partition by dt.id_debito_trabalhista, dist.id_processo_trf order by dist.dt_log desc) linha_dist,
        rank() over (partition by pdi.id_pessoa order by pdi.id_pessoa_doc_identificacao) linha_pdi
    from tb_debito_trabalhista dt
    join tb_sit_debito_trabalhista sdt_ultimo_envio using (id_situacao_debito_trabalhista)
    join tb_processo_parte pp using (id_processo_parte)
    join tb_processo proc on proc.id_processo = pp.id_processo_trf
    join tb_processo_trf ptrf on proc.id_processo = ptrf.id_processo_trf
    join tb_pess_doc_identificacao pdi using(id_pessoa)
    join tb_usuario_login ul on ul.id_usuario = pp.id_pessoa
    -- Relacionamento abaixo pode retornar mais de um registro do histórico do débito por id_processo_parte e id_situacao_debito_trabalhista.
    -- Logo, na projeção tivemos que fazer o rank e selecionar o primeiro registro, o com data de envio mais recente
    join tb_dbto_trblhsta_historico dth on (dth.id_processo_parte = pp.id_processo_parte)
    join tb_sit_debito_trabalhista sdt on sdt.id_situacao_debito_trabalhista = dth.id_situacao_debito_trabalhista
    -- Relacionamento abaixo pode retornar mais de um registro de log de distribuição por processo
    -- Então na projeção tivemos que fazer o rank e selecionar a distribuição imediatamente anterior a data da inclusão do débito trabalhista
    LEFT JOIN ( SELECT tb_processo_trf_log_dist.id_orgao_julgador,
        tb_processo_trf_log.id_processo_trf,
        tb_processo_trf_log.dt_log
       FROM tb_processo_trf_log join tb_processo_trf_log_dist ON tb_processo_trf_log.id_processo_trf_log = tb_processo_trf_log_dist.id_processo_trf_log
      ) dist ON proc.id_processo::integer = dist.id_processo_trf
    -- Relacionamento abaixo pode retornar mais de um registro de histrico de deslocamento do processo
    -- Então na projeção tivemos que fazer o rank e selecionar o deslocamento imediatamente anterior a data da inclusão do débito trabalhista
    LEFT JOIN tb_hist_desloca_oj desloc ON proc.id_processo::integer = desloc.id_processo_trf
    where pdi.in_ativo = 'S'
        and pdi.in_principal = 'S'
        and pdi.cd_tp_documento_identificacao in ('CPF', 'CPJ')
        -- não considera os débitos excluídos
and dt.id_situacao_debito_trabalhista <> 4
        -- A partir daqui, filtros possíveis e opcionais
        and dth.cd_erro_bndt is null
        -- identifica os deslocamentos anteriores a data da inclusão do débito (se não tiver deslocamento, ok também, pois utilizará o oj da distribuição)
        and (desloc.dt_deslocamento is null or (dt_deslocamento::date <= dth.dt_envio::date and (desloc.dt_retorno is null or desloc.dt_retorno::date >= dth.dt_envio::date)))
        -- Identifica distribuições anteriores a data da inclusão do débito
        and (dist.dt_log is null or dist.dt_log::date <= dth.dt_envio::date)
  ) tmp
  join tb_orgao_julgador oj on (oj.id_orgao_julgador = tmp.id_orgao_julgador)
  where
  linha_dth = 1 -- seleciona o registro mais recente do histórico do débito
  and linha_desloc = 1 -- seleciona o registro mais recente do histórico de deslocamento antes da data da inclusão do débito
  and linha_dist = 1 -- seleciona o registro mais recente do histórico de distribuição antes da data da inclusão do débito
  and linha_pdi = 1
  and tmp.id_orgao_julgador = coalesce(:ORGAO_JULGADOR_TODOS, tmp.id_orgao_julgador)
  and tmp.dt_envio::date between (:DATA_INICIAL)::date and ((coalesce(:DATA_OPCIONAL_FINAL, current_date))::date + interval '24 hours')
  and tmp.id_situacao_debito_trabalhista_sucesso = coalesce (:ID_SITUACAO_DEB_TRAB, tmp.id_situacao_debito_trabalhista_sucesso)
  group by 1, 2, 4
  having count(tmp.nr_documento_identificacao) >= COALESCE(:NUMERO_MINIMO, 20)
order by 3 desc

