    pt.nm_tarefa as "Tarefa"
 INNER JOIN tb_processo_tarefa pt on pt.id_processo_trf = p.id_processo
     AND pt.id_tarefa = COALESCE(:TAREFA, pt.id_tarefa)

