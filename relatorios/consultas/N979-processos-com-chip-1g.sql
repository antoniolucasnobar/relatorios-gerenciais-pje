-- [R144010][N979] 2020-10-07 - adicao de novos filtros por etiqueta.
-- [R144010] - 2020-10-22 - adicao do filtro por cargo do processo (nem todos tem chip j1/j2)
with t1 as(
--T1 contém a maioria das regras, somente não tem o filtro pela fase processual
select
    REPLACE(oj.ds_orgao_julgador, 'VARA DO TRABALHO', 'VT' ) AS "Órgão Julgador",
	ptrf.id_processo_trf,
	classe.ds_classe_judicial_sigla as "Classe Judicial",
    cargo.cd_cargo as "Cargo",
	procxtar.nm_tarefa as "Tarefa atual"
from
	tb_processo_trf ptrf
join
	tb_classe_judicial classe using (id_classe_judicial)
join
	tb_orgao_julgador oj on (ptrf.id_orgao_julgador = oj.id_orgao_julgador)
join
        tb_processo_tarefa procxtar on (ptrf.id_processo_trf = procxtar.id_processo_trf)
join
	tb_etq_processo_etiqueta peq on (ptrf.id_processo_trf = peq.id_processo_trf)
join
	tb_etq_etiqueta_instancia eqi on (eqi.id_etq_etiqueta_instancia = peq.id_etq_etiqueta_instancia)
join
	tb_etq_etiqueta eq on (eq.id_etq_etiqueta = eqi.id_etq_etiqueta)
inner join tb_orgao_julgador_cargo ojc ON (ptrf.id_orgao_julgador_cargo = ojc.id_orgao_julgador_cargo)
inner join tb_cargo cargo ON (ojc.id_cargo = cargo.id_cargo)
where
	coalesce(:ORGAO_JULGADOR_TODOS, oj.id_orgao_julgador) = oj.id_orgao_julgador
	AND  ((:CARGO is null) or (position(:CARGO in ojc.ds_cargo) > 0))
  AND  (
    CASE
        WHEN :ID_ETIQUETA IS NULL THEN TRUE
        ELSE EXISTS(SELECT 1
                    FROM 	tb_etq_processo_etiqueta ppeq
                                join tb_etq_etiqueta_instancia eeqi on
                                (eeqi.id_etq_etiqueta_instancia = ppeq.id_etq_etiqueta_instancia)
                    WHERE
                        (ptrf.id_processo_trf = ppeq.id_processo_trf)
                        AND :ID_ETIQUETA = eeqi.id_etq_etiqueta
            )
        END
    )
  AND  (
    CASE
        WHEN :ID_ETIQUETA2 IS NULL THEN TRUE
        ELSE EXISTS(SELECT 1
                    FROM 	tb_etq_processo_etiqueta ppeq
                                join tb_etq_etiqueta_instancia eeqi on
                        (eeqi.id_etq_etiqueta_instancia = ppeq.id_etq_etiqueta_instancia)
                    WHERE
                        (ptrf.id_processo_trf = ppeq.id_processo_trf)
                      AND :ID_ETIQUETA2 = eeqi.id_etq_etiqueta
            )
        END
    )
  AND  (
    CASE
        WHEN :ID_ETIQUETA3 IS NULL THEN TRUE
        ELSE EXISTS(SELECT 1
                    FROM 	tb_etq_processo_etiqueta ppeq
                                join tb_etq_etiqueta_instancia eeqi on
                        (eeqi.id_etq_etiqueta_instancia = ppeq.id_etq_etiqueta_instancia)
                    WHERE
                        (ptrf.id_processo_trf = ppeq.id_processo_trf)
                      AND :ID_ETIQUETA3 = eeqi.id_etq_etiqueta
            )
        END
    )
	and ptrf.cd_processo_status = 'D'
    group by 	oj.ds_orgao_julgador,
	ptrf.id_processo_trf,
	classe.ds_classe_judicial_sigla,
    cargo.cd_cargo,
	procxtar.nm_tarefa
)
select
	'http://processo='||p.nr_processo||'&grau=primeirograu&recurso=$RECURSO_PJE_DETALHES_PROCESSO' as " ",
	'http://processo='||p.nr_processo||'&grau=primeirograu&recurso=$RECURSO_PJE_TAREFA&texto='||p.nr_processo as "Processo" ,
	t1."Órgão Julgador",
	t1."Classe Judicial",
	t1."Cargo",
    (SELECT string_agg(eq.nm_etiqueta || ' (' || to_char(peq.dh_inclusao, 'dd/mm/yyyy') || ')', ', ') FROM
        tb_etq_processo_etiqueta peq
            join
        tb_etq_etiqueta_instancia eqi on (eqi.id_etq_etiqueta_instancia = peq.id_etq_etiqueta_instancia)
            join
        tb_etq_etiqueta eq on (eq.id_etq_etiqueta = eqi.id_etq_etiqueta)
     where peq.id_processo_trf = t1.id_processo_trf
        ) AS "Chips/Etiquetas (data de inclusão)",
    fase.nm_agrupamento_fase as "Fase Processual",
	t1."Tarefa atual"
from t1
join
	tb_processo p on (p.id_processo = t1.id_processo_trf)
join
	tb_agrupamento_fase fase on (fase.id_agrupamento_fase = p.id_agrupamento_fase)
where
coalesce(:ID_FASE_PROCESSUAL, fase.id_agrupamento_fase) = fase.id_agrupamento_fase
and fase.in_ativo = 'S' and nm_agrupamento_fase not like all (array['Elabora__o', 'Finalizados'])
order by t1."Órgão Julgador", p.nr_processo


