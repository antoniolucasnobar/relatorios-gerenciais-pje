  SELECT 'http://processo='||p.nr_processo||'&grau=primeirograu&recurso=$RECURSO_PJE_DETALHES_PROCESSO' as " ",
        'http://processo='||p.nr_processo||'&grau=primeirograu&recurso=$RECURSO_PJE_TAREFA&texto='||cj.ds_classe_judicial_sigla||' '||p.nr_processo as "Processo",
    REPLACE(oj.ds_orgao_julgador, 'VARA DO TRABALHO', 'VT') AS "Unidade",
    REPLACE(pe.ds_texto_final_interno, 'Prejudicado o incidente', '') as "Prejudicado o incidente", 
    pe.dt_atualizacao as "Data Movimento",
    fase.nm_agrupamento_fase as "Fase",
    pt.nm_tarefa as "Tarefa"
from tb_processo p
	inner join tb_processo_trf ptrf on ptrf.id_processo_trf = p.id_processo
	inner join tb_orgao_julgador oj on oj.id_orgao_julgador = ptrf.id_orgao_julgador
	inner join tb_processo_evento pe on pe.id_processo = p.id_processo
    inner join tb_processo_tarefa pt on pt.id_processo_trf = p.id_processo
    inner join tb_agrupamento_fase fase on (p.id_agrupamento_fase = fase.id_agrupamento_fase)
    INNER JOIN tb_classe_judicial cj ON (cj.id_classe_judicial = ptrf.id_classe_judicial)
where p.id_agrupamento_fase <> 5
    and pe.dt_atualizacao:: date between (:DATA_INICIAL)::date and (:DATA_FINAL)::date
    and oj.id_orgao_julgador = coalesce(:ORGAO_JULGADOR_TODOS, oj.id_orgao_julgador)
    AND fase.id_agrupamento_fase = coalesce(:ID_FASE_PROCESSUAL, fase.id_agrupamento_fase)
	and pe.id_evento = 50049
    -- and pe.id_processo_evento_excludente is null -- retirado por divergencia com o SERP
	and 
		(pe.ds_texto_final_interno ilike 'Prejudicado o incidente Impugnação à Sentença de Liquidação%' or 
		pe.ds_texto_final_interno ilike 'Prejudicado o incidente Embargos à Execução%' or 
		pe.ds_texto_final_interno ilike 'Prejudicado o incidente Embargos à Arrematação%' or 
		pe.ds_texto_final_interno ilike 'Prejudicado o incidente Embargos à Adjudicação%' or 
		pe.ds_texto_final_interno ilike 'Exceção de Pré-executividade%'
		)
	and not exists (select * 
							  from tb_processo_evento pe2 
							  where pe2.id_processo = p.id_processo 
							  	and pe2.id_evento = 50087 
							  	and pe2.dt_atualizacao > pe.dt_atualizacao
							  	and (
							  		(pe2.ds_texto_final_interno ilike '%Impugnação à Sentença de Liquidação%' and pe.ds_texto_final_interno ilike '%Impugnação à Sentença de Liquidação%') or 
							  		(pe2.ds_texto_final_interno ilike '%Embargos à Execução%' and pe.ds_texto_final_interno ilike '%Embargos à Execução%') or 
							  		(pe2.ds_texto_final_interno ilike '%Embargos à Arrematação%' and pe.ds_texto_final_interno ilike '%Embargos à Arrematação%') or 
							  		(pe2.ds_texto_final_interno ilike '%Embargos à Adjudicação%' and pe.ds_texto_final_interno ilike '%Embargos à Adjudicação%') or 
							  		(pe2.ds_texto_final_interno ilike '%Exceção de Pré-executividade%' and pe.ds_texto_final_interno ilike '%Exceção de Pré-executividade%')
							  	)
							  )
order by pe.dt_atualizacao

