-- [T921][52651] erros no DEJT
SELECT 'http://processo='||p.nr_processo||'&grau=primeirograu&recurso=$RECURSO_PJE_DETALHES_PROCESSO' as " "
     ,  'http://processo='||p.nr_processo||'&grau=primeirograu&recurso=$RECURSO_PJE_TAREFA&texto='||p.nr_processo as "Processo"
     , date_trunc('minute',dt_criacao_expediente) as "Data de criação"
     , REPLACE(oj.ds_orgao_julgador, 'VARA DO TRABALHO', 'VT' ) as "Unidade"
     , ds_nome AS "Publicador"
     , tx_erro AS "Mensagem de Erro"
     , pt.nm_tarefa as "Tarefa"
from tb_dejt_publicacao_erro
         inner join tb_dejt_publicacao dp1 using (id_dejt_publicacao)
         inner join tb_usuario_login on id_usuario = id_usuario_criacao
         inner join tb_orgao_julgador oj using (id_orgao_julgador)
         inner join tb_processo_expediente pe1 using (id_processo_expediente)
         inner join tb_processo p on id_processo = id_processo_trf
         inner join tb_processo_tarefa pt on pt.id_processo_trf = p.id_processo
         inner join tb_jurisdicao using (id_jurisdicao)
         inner join tb_proc_parte_expediente ppe1 using (id_processo_expediente)
where
        id_dejt_situacao_publicacao = :SITUACAO_PUBLICACAO
  AND oj.id_orgao_julgador = coalesce(:ORGAO_JULGADOR_TODOS, oj.id_orgao_julgador)
  and ppe1.in_fechado = 'N'
  AND (dt_criacao_expediente BETWEEN coalesce(:DATA_INICIAL_OPCIONAL, date_trunc('year', current_date))::date
    AND ((coalesce(:DATA_OPCIONAL_FINAL, current_date))::date + interval '24 hours'))
  AND (
    CASE (:COM_PUBLICACAO_POSTERIOR)
        WHEN 0 THEN
            not exists (select 1 from tb_dejt_publicacao dp2 inner join tb_processo_expediente pe2 on pe2.id_processo_expediente = dp2.id_processo_expediente where dp2.dh_criacao > dp1.dh_criacao and dp2.id_dejt_situacao_publicacao IN (2,4) and pe2.id_processo_trf = p.id_processo)
        WHEN 1 THEN
            exists (select 1 from tb_dejt_publicacao dp2 inner join tb_processo_expediente pe2 on pe2.id_processo_expediente = dp2.id_processo_expediente where dp2.dh_criacao > dp1.dh_criacao and dp2.id_dejt_situacao_publicacao IN (2,4) and pe2.id_processo_trf = p.id_processo)
        ELSE TRUE
        END
    )
  AND pt.id_tarefa = COALESCE(:TAREFA, pt.id_tarefa)
  AND CASE
          WHEN  length(TRIM(COALESCE(:MENSAGEM_ERRO, ''))) = 0 THEN TRUE
          ELSE tx_erro ILIKE '%' || :MENSAGEM_ERRO || '%'
    END
order by ds_orgao_julgador, dt_criacao_expediente
