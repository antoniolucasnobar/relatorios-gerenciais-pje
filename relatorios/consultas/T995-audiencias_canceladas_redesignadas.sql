with audiencias_canceladas_remarcadas as (
                select pa.dt_inicio as dta_audiencia,
                p.id_processo,
                p.nr_processo,
                p.id_agrupamento_fase,
                pa.dt_cancelamento,
                case when pa.cd_status_audiencia = 'C' then 'Cancelada'
                    when pa.cd_status_audiencia = 'R' then 'Redesignada'
                    else pa.cd_status_audiencia
                   end as cd_status_audiencia,
                ptrf.id_orgao_julgador_cargo,
                       --Cálculo conforme RN05
                case when pa.cd_status_audiencia = 'R' then
                (
                   SELECT pa2.dt_inicio
                   FROM tb_processo_audiencia pa2
                   WHERE pa2.id_processo_trf = ptrf.id_processo_trf
                     AND pa2.cd_status_audiencia = 'M' and pa2.in_ativo = 'S'
                     AND pa2.dt_inicio > pa.dt_inicio
                ) END as dt_proxima_audiencia,
                sala.id_orgao_julgador  as id_orgao_julgador,
                ta.ds_tipo_audiencia,
                ti.name_,
                ti.start_
                from tb_processo_audiencia pa
                join tb_tipo_audiencia ta using (id_tipo_audiencia)
                join tb_processo p on (pa.id_processo_trf = p.id_processo)
                join tb_processo_trf ptrf on (pa.id_processo_trf = ptrf.id_processo_trf)
                join tb_classe_judicial cl on (cl.id_classe_judicial = ptrf.id_classe_judicial)
                join tb_processo_instance procxins on (p.id_processo = procxins.id_processo)
                join jbpm_taskinstance ti on (procxins.id_proc_inst = ti.procinst_ and ti.end_ is null and ti.isopen_ = 'true')
                join tb_sala_fisica sala on (pa.id_sala_fisica = sala.id_sala_fisica)
                -- somente canceladas ou redesignadas
                where pa.cd_status_audiencia  IN ('C','R') and pa.in_ativo = 'S'
                --Processo não deve estar arquivado RN06 e nem na instância superior RN10
                and ti.name_ not in ('Arquivo', 'Arquivo provisório','Arquivo definitivo', 'Arquivamento Provisório', 'Arquivamento Definitivo', 'Aguardando apreciação da instância superior',
                        'Aguardando apreciação pela instância superior')
                AND NOT EXISTS (
                        SELECT 1
                        FROM tb_processo_audiencia pa2
                        WHERE pa2.id_processo_trf = ptrf.id_processo_trf
                        AND pa2.cd_status_audiencia  IN ('C','R','F') and pa2.in_ativo = 'S'
                        AND (pa2.dt_inicio > pa.dt_inicio OR (pa2.dt_inicio = pa.dt_inicio AND pa2.dt_cancelamento > pa.dt_cancelamento))
                )
                AND sala.id_orgao_julgador = coalesce(:ORGAO_JULGADOR_TODOS,sala.id_orgao_julgador) --Incluir o parâmetro de filtro OJ
                and ((:ID_TIPO_AUDIENCIA  is null) or (:ID_TIPO_AUDIENCIA  = ta.id_tipo_audiencia))
                )
                SELECT
                'http://processo='||pe.nr_processo||'&grau=primeirograu&recurso=$RECURSO_PJE_DETALHES_PROCESSO' as " ",
                'http://processo='||pe.nr_processo||'&grau=primeirograu&recurso=$RECURSO_PJE_TAREFA&texto='||pe.nr_processo as "Processo",

                (SELECT trim(ul1.ds_nome) FROM tb_usuario_login ul1 WHERE ativo1.id_pessoa = ul1.id_usuario) 
                || CASE
                        WHEN (ativo2.id_pessoa IS NOT NULL) THEN ' E OUTROS (' ||
                         (SELECT COUNT(pp.id_processo_trf) FROM tb_processo_parte pp
                                WHERE (pp.id_processo_trf = pe.id_processo
                                        AND pp.in_participacao in ('A')
                                        AND pp.in_parte_principal = 'S'
                                        AND pp.in_situacao = 'A'
                                        )
                         ) || ')'
                        ELSE ''
                   END AS "Polo Ativo"
                   ,
                -- || ' X ' ||
                (SELECT trim(ul1.ds_nome) FROM tb_usuario_login ul1 WHERE passivo1.id_pessoa = ul1.id_usuario) 
                || CASE
                        WHEN (passivo2.id_processo_trf IS NOT NULL) THEN ' E OUTROS (' ||
                         (SELECT COUNT(pp.id_processo_trf) FROM tb_processo_parte pp
                                WHERE (pp.id_processo_trf = pe.id_processo
                                        AND pp.in_participacao in ('P')
                                        AND pp.in_parte_principal = 'S'
                                        AND pp.in_situacao = 'A'
                                       )
                         ) || ')'
                        ELSE ''
                   END
                 AS "Polo Passivo",
                cargo.cd_cargo as "Cargo",
                -- ojc.ds_cargo as "Cargo",
                to_char(pe.dta_audiencia,'dd/MM/yyyy HH24:mi:ss') as "Data da designação anterior",
                to_char(pe.dt_cancelamento,'dd/MM/yyyy HH24:mi:ss') as "Data do cancelamento",
                to_char(pe.dt_proxima_audiencia,'dd/MM/yyyy HH24:mi:ss') as "Data Próxima audiência",
                pe.ds_tipo_audiencia as "Tipo da Audiência",
                pe.cd_status_audiencia as "Status",
                substring(UPPER(TRIM(fase.nm_agrupamento_fase)) FROM 0 FOR 4) || ' / ' || -- as "Fase",
                pe.name_ as "Fase / Tarefa Atual"
                
                from audiencias_canceladas_remarcadas pe
                inner join tb_orgao_julgador oje on (pe.id_orgao_julgador = oje.id_orgao_julgador)
                inner join tb_agrupamento_fase fase on (pe.id_agrupamento_fase = fase.id_agrupamento_fase)
                inner join tb_orgao_julgador_cargo ojc ON (pe.id_orgao_julgador_cargo = ojc.id_orgao_julgador_cargo)
                inner join tb_cargo cargo ON (ojc.id_cargo = cargo.id_cargo)
                INNER JOIN tb_processo_parte ativo1 ON 
                        (ativo1.id_processo_trf = pe.id_processo
                                AND ativo1.in_participacao in ('A')
                                AND ativo1.in_parte_principal = 'S'
                                AND ativo1.in_situacao = 'A'
                                AND ativo1.nr_ordem = 1
                        )
                INNER JOIN tb_processo_parte passivo1 ON 
                        (passivo1.id_processo_trf = pe.id_processo
                                AND passivo1.in_participacao in ('P')
                                AND passivo1.in_parte_principal = 'S'
                                AND passivo1.in_situacao = 'A'
                               AND passivo1.nr_ordem = 1
                        )
                 LEFT JOIN tb_processo_parte ativo2 ON 
                        (ativo2.id_processo_trf = pe.id_processo
                                AND ativo2.in_participacao in ('A')
                                AND ativo2.in_parte_principal = 'S'
                                AND ativo2.in_situacao = 'A'
                                AND ativo2.nr_ordem = 2
                        )
                  LEFT JOIN tb_processo_parte passivo2 ON 
                        (passivo2.id_processo_trf = pe.id_processo
                                AND passivo2.in_participacao in ('P')
                                AND passivo2.in_parte_principal = 'S'
                                AND passivo2.in_situacao = 'A'
                                AND passivo2.nr_ordem = 2
                        )              
                WHERE
                ((:CARGO is null) or (position(:CARGO in ojc.ds_cargo) > 0))
                and ((:ID_FASE_PROCESSUAL is null) or (:ID_FASE_PROCESSUAL = pe.id_agrupamento_fase))
                and ((pe.dta_audiencia BETWEEN to_timestamp(:DATA_INICIAL, 'yyyy-MM-dd' )
                           and (to_timestamp(:DATA_FINAL, 'yyyy-MM-dd' ) + interval '24 hours')))
                AND ((:NOME_PARTE is null) or 
                        ( 
                          (:NOME_PARTE is NOT null) AND
                          EXISTS(
                                SELECT 1 FROM tb_processo_parte pp
                                INNER JOIN tb_usuario_login usu ON (usu.id_usuario = pp.id_pessoa)
                                WHERE pp.id_processo_trf = pe.id_processo
                                AND pp.in_parte_principal = 'S'
                                AND pp.in_situacao = 'A'
                                AND pp.in_participacao in ('A','P')
                                AND usu.ds_nome_consulta LIKE '%' || UPPER(:NOME_PARTE) || '%'
                          )  
                        )
                ) 
                --O processo não pode estar concluso para julgamento RN03
                and not exists (
                select 1
                from tb_processo_evento pe2
                        join tb_evento_processual e2 on (pe2.id_evento = e2.id_evento_processual)
                        where e2.cd_evento  = '51' and pe2.dt_atualizacao > pe.dta_audiencia
                        and pe2.id_processo = pe.id_processo
                        and pe2.id_processo_evento_excludente IS NULL
                        and  exists ( select 1
                          from tb_complemento_segmentado cs
                          join tb_tipo_complemento tc on (cs.id_tipo_complemento = tc.id_tipo_complemento)
                          where cs.id_movimento_processo=pe2.id_processo_evento
                          and tc.cd_tipo_complemento = '3'
                          and cs.ds_texto = '36'
                        )
                        and  exists ( select 1
                          from tb_complemento_segmentado cs
                          join tb_tipo_complemento tc on (cs.id_tipo_complemento = tc.id_tipo_complemento)
                          where cs.id_movimento_processo=pe2.id_processo_evento
                          and tc.cd_tipo_complemento = '5015'
                          and cs.ds_texto = '7020'
                        )
                        --Não foi convertido em diligencia ou teve a conclusão encerrada
                        and not exists (select 1
                                from tb_processo_evento pe3
                                join tb_evento_processual e3 on (pe3.id_evento = e3.id_evento_processual)
                                where e3.cd_evento  in ('11022','50086') and pe3.dt_atualizacao >= pe2.dt_atualizacao
                                and pe3.id_processo = pe2.id_processo
                                and pe3.id_processo_evento_excludente IS NULL
                        )
                )
                order by 5,2