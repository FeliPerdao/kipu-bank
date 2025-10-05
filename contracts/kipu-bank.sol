// SPDX-License-Identifier: MIT
pragma solidity >0.8.0;

/**
 * @title Contrato kipu-bank
 * @author FeliPerdao
 * @notice Contrato para almacenamiento de tokens y funciones de retiro/depósito como un banco
 * @dev Este contrato es solo para propósitos de aprendizaje
 * @custom:security No uses este código en producción
 */

contract ToDoList {

    enum State {
        Created,
        Completed
    }
    
    ///@notice Estructura para almacenar información de tareas
    struct Task {
        string description;
        uint256 creationTime; 
        uint256 index;
        State state;
    }

    ///@notice Array para almacenar la estructura de datos
    Task[] private s_task;
    uint256 private taskCount;

    error InvalidValue();

    ///@notice Evento emitido cuando se añade una tarea nueva
    event AddedTask(uint256 indexed index, string indexed description, uint256 creationTime);
    ///@notice Evento emitido cuando una tarea es completada y eliminada
    event CompletedAndEliminated(string _description);
    ///@notice Evento cuando el status de una tarea es modificado
    event TaskStatusChanged(uint256 indexed index, string indexed description, string indexed newStatus);
    ///@notice evento cuando es pagado
    event paid(address indexed payer, uint256 amount);

    mapping(address=>uint256) public balance; 

    /**
     * @notice Función para añadir tareas al alamcenamiento del contrato
     * @param _description La descripción de la tarea que se está añadiendo
     */
    function setTask(string calldata _description) external {
        uint256 _taskCount = taskCount++;
        s_task.push(Task(_description, block.timestamp, _taskCount, State.Created));
        emit AddedTask(_taskCount, _description, block.timestamp);
    }

    function deleteTask(string calldata _description) external {
        uint256 len = s_task.length;
        for(uint256 i; i<len;) {
            if(keccak256(bytes(s_task[i].description)) == keccak256(bytes(_description))) { //Casteamos la descriptción en bytes
                emit TaskStatusChanged(s_task[i].index, s_task[i].description, "eliminado");
                s_task[i] = s_task[len - 1]; //reemplazamos el elemento a borrar con el último
                s_task.pop(); //borramos el último elemento
                emit CompletedAndEliminated(_description);

                return;

            }
            unchecked {
                ++i;
            }
        }
    } 
    
    /**
     * @notice Funcion que retorna todas las tareas almacenadas en el array s_task
     */
    function getTask() external view returns (Task[] memory) {
        return s_task;
    }

    function completeTask(string calldata _description) external {
        uint256 len = s_task.length;
        for(uint256 i; i<len;) {
            if(keccak256(bytes(s_task[i].description)) == keccak256(bytes(_description))) { //Casteamos la descriptción en bytes
                emit TaskStatusChanged(s_task[i].index, s_task[i].description, "completado");
                s_task[i].state = State.Completed;
                break;
            }
            unchecked {
                ++i;
            }
        }
    } 
}